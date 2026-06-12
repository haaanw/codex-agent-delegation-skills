#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s "external research request"\n' "$0" >&2
}

if [ "$#" -eq 0 ]; then
  usage
  exit 64
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$script_dir/common.sh"

agent_require_command curl "curl is not installed or not on PATH."
agent_require_command python3 "python3 is required to build and parse Perplexity API JSON."
agent_require_any_env "Perplexity API" PERPLEXITY_API_KEY

repo_root="$(agent_repo_root)"
cd "$repo_root"

request="$*"
model="${PERPLEXITY_MODEL:-sonar-pro}"

prompt="$(cat <<EOF
You are Perplexity running as a delegated external research agent for Codex.

Research task:
$request

Hard boundaries:
- Codex is the orchestrator. You are a single delegate.
- Gather only current external information from the web.
- Do not use, request, infer, inspect, or summarize local repository files.
- Do not call Claude, Gemini, Kimi, GLM, DeepSeek, MiniMax, Perplexity, Codex, or any other agent.
- Do not inspect or discuss .codex, .claude, CLAUDE.md, AGENTS.md, or agent config files.
- Return citations for factual claims. Prefer primary sources and official documentation when available.

Return a concise research brief with dated facts where relevant and citation markers in the text.
EOF
)"

tmp_response="$(mktemp "${TMPDIR:-/tmp}/codex-perplexity-response.XXXXXX")"
cleanup() {
  rm -f "$tmp_response"
}
trap cleanup EXIT HUP INT TERM

PERPLEXITY_PROMPT="$prompt" PERPLEXITY_MODEL_NAME="$model" python3 - <<'PY' | curl \
  --silent \
  --show-error \
  --fail \
  --request POST \
  --url https://api.perplexity.ai/v1/sonar \
  --header "Authorization: Bearer ${PERPLEXITY_API_KEY}" \
  --header 'Content-Type: application/json' \
  --data-binary @- > "$tmp_response"
import json
import os

payload = {
    "model": os.environ["PERPLEXITY_MODEL_NAME"],
    "messages": [
        {
            "role": "user",
            "content": os.environ["PERPLEXITY_PROMPT"],
        }
    ],
}

print(json.dumps(payload))
PY

python3 - "$tmp_response" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)

choices = data.get("choices") or []
content = ""
if choices:
    content = ((choices[0].get("message") or {}).get("content") or "").strip()

citations = data.get("citations") or []
search_results = data.get("search_results") or []

if not content:
    sys.stderr.write("Error: Perplexity response did not include message content.\n")
    sys.exit(65)

if not citations:
    sys.stderr.write("Error: Perplexity response did not include citations.\n")
    sys.exit(65)

print(content)
print()
print("Citations:")
for index, url in enumerate(citations, 1):
    print(f"[{index}] {url}")

if search_results:
    print()
    print("Search Results:")
    for index, result in enumerate(search_results, 1):
        title = result.get("title") or "Untitled"
        url = result.get("url") or ""
        date = result.get("date") or result.get("last_updated") or ""
        if date:
            print(f"[{index}] {title} ({date}) - {url}")
        else:
            print(f"[{index}] {title} - {url}")
PY
