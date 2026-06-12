#!/usr/bin/env bash
set -euo pipefail

agent_require_command_local() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf 'Error: %s is not installed or not on PATH.\n' "$cmd" >&2
    exit 127
  fi
}

agent_require_command_local curl
agent_require_command_local python3

if command -v git >/dev/null 2>&1 && repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  repo_root="$(pwd)"
fi

cd "$repo_root"

provider="${DELEGATE_PROVIDER_NAME:-OpenAI-compatible provider}"
endpoint="${DELEGATE_ENDPOINT:-}"
model="${DELEGATE_MODEL:-}"
api_key="${DELEGATE_API_KEY:-}"
prompt="${DELEGATE_PROMPT:-}"
system_prompt="${DELEGATE_SYSTEM_PROMPT:-You are a concise senior engineering delegate.}"
extra_body="${DELEGATE_EXTRA_BODY:-}"

if [ -z "$endpoint" ]; then
  printf 'Error: DELEGATE_ENDPOINT is not set for %s.\n' "$provider" >&2
  exit 64
fi

if [ -z "$model" ]; then
  printf 'Error: DELEGATE_MODEL is not set for %s.\n' "$provider" >&2
  exit 64
fi

if [ -z "$api_key" ]; then
  printf 'Error: DELEGATE_API_KEY is not set for %s.\n' "$provider" >&2
  exit 78
fi

if [ -z "$prompt" ]; then
  printf 'Error: DELEGATE_PROMPT is empty for %s.\n' "$provider" >&2
  exit 64
fi

tmp_request="$(mktemp "${TMPDIR:-/tmp}/codex-agent-request.XXXXXX")"
tmp_response="$(mktemp "${TMPDIR:-/tmp}/codex-agent-response.XXXXXX")"
tmp_error="$(mktemp "${TMPDIR:-/tmp}/codex-agent-error.XXXXXX")"
cleanup() {
  rm -f "$tmp_request" "$tmp_response" "$tmp_error"
}
trap cleanup EXIT HUP INT TERM

DELEGATE_REQUEST_JSON="$tmp_request" python3 - <<'PY'
import json
import os
import sys

payload = {
    "model": os.environ["DELEGATE_MODEL"],
    "messages": [
        {
            "role": "system",
            "content": os.environ.get("DELEGATE_SYSTEM_PROMPT", "You are a concise senior engineering delegate."),
        },
        {
            "role": "user",
            "content": os.environ["DELEGATE_PROMPT"],
        },
    ],
}

temperature = os.environ.get("DELEGATE_TEMPERATURE")
if temperature:
    payload["temperature"] = float(temperature)

max_tokens = os.environ.get("DELEGATE_MAX_TOKENS")
if max_tokens:
    payload["max_tokens"] = int(max_tokens)

extra = os.environ.get("DELEGATE_EXTRA_BODY")
if extra:
    try:
        payload.update(json.loads(extra))
    except json.JSONDecodeError as exc:
        sys.stderr.write(f"Error: DELEGATE_EXTRA_BODY is not valid JSON: {exc}\n")
        sys.exit(64)

with open(os.environ["DELEGATE_REQUEST_JSON"], "w", encoding="utf-8") as handle:
    json.dump(payload, handle)
PY

if ! curl \
  --silent \
  --show-error \
  --fail \
  --request POST \
  --url "$endpoint" \
  --header "Authorization: Bearer ${api_key}" \
  --header 'Content-Type: application/json' \
  --data-binary "@$tmp_request" \
  > "$tmp_response" 2> "$tmp_error"; then
  printf 'Error: %s request failed.\n' "$provider" >&2
  sed -n '1,120p' "$tmp_error" >&2
  exit 65
fi

python3 - "$tmp_response" "$provider" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)

error = data.get("error")
if error:
    sys.stderr.write(f"Error from {sys.argv[2]}: {error}\n")
    sys.exit(65)

choices = data.get("choices") or []
if not choices:
    sys.stderr.write(f"Error: {sys.argv[2]} response did not include choices.\n")
    sys.exit(65)

message = choices[0].get("message") or {}
content = message.get("content")

if isinstance(content, list):
    pieces = []
    for item in content:
        if isinstance(item, dict):
            pieces.append(str(item.get("text") or item.get("content") or ""))
        else:
            pieces.append(str(item))
    content = "".join(pieces)

if content is None:
    content = ""

content = str(content).strip()
if not content:
    sys.stderr.write(f"Error: {sys.argv[2]} response did not include message content.\n")
    sys.exit(65)

print(content)
PY
