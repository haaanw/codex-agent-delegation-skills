#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: $0 [--apply] --file path [--file path...] "bounded task"

DeepSeek execute is intentionally file-scoped. It reads only explicit files,
asks DeepSeek for a unified diff, and prints the patch by default.
Use --apply only when the user explicitly approves applying the generated patch.
EOF
}

apply_patch=0
files=()
args=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      apply_patch=1
      shift
      ;;
    --file)
      if [ "$#" -lt 2 ]; then
        usage
        exit 64
      fi
      files+=("$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

if [ "${#args[@]}" -eq 0 ] || [ "${#files[@]}" -eq 0 ]; then
  usage
  exit 64
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$script_dir/common.sh"

agent_require_command curl "curl is not installed or not on PATH."
agent_require_command python3 "python3 is required for OpenAI-compatible API JSON handling."
agent_require_any_env "DeepSeek API" DEEPSEEK_API_KEY

if [ "$apply_patch" -eq 1 ]; then
  agent_require_command git "git is required to apply DeepSeek-generated patches."
fi

repo_root="$(agent_repo_root)"
cd "$repo_root"

task="${args[*]}"
max_bytes="${DEEPSEEK_FILE_MAX_BYTES:-120000}"

tmp_context="$(mktemp "${TMPDIR:-/tmp}/codex-deepseek-context.XXXXXX")"
tmp_patch="$(mktemp "${TMPDIR:-/tmp}/codex-deepseek.patch.XXXXXX")"
cleanup() {
  rm -f "$tmp_context" "$tmp_patch"
}
trap cleanup EXIT HUP INT TERM

normalized_files=()
for raw_file in "${files[@]}"; do
  rel_file="$(agent_normalize_repo_path "$repo_root" "$raw_file")" || {
    printf 'Error: file is outside the repository: %s\n' "$raw_file" >&2
    exit 64
  }

  if agent_forbidden_path "$rel_file"; then
    printf 'Error: DeepSeek execute may not inspect or modify agent config path: %s\n' "$rel_file" >&2
    exit 64
  fi

  if [ ! -f "$rel_file" ]; then
    printf 'Error: file does not exist: %s\n' "$rel_file" >&2
    exit 66
  fi

  python3 - "$rel_file" "$max_bytes" <<'PY'
import os
import sys

path = sys.argv[1]
max_bytes = int(sys.argv[2])
size = os.path.getsize(path)

if size > max_bytes:
    sys.stderr.write(f"Error: {path} is {size} bytes, above limit {max_bytes}.\n")
    sys.exit(65)

with open(path, "rb") as handle:
    sample = handle.read()

if b"\0" in sample:
    sys.stderr.write(f"Error: {path} appears to be binary; refusing to send to DeepSeek.\n")
    sys.exit(65)
PY

  normalized_files+=("$rel_file")
done

for rel_file in "${normalized_files[@]}"; do
  {
    printf '### File: %s\n' "$rel_file"
    printf '```text\n'
    sed -n '1,4000p' "$rel_file"
    printf '\n```\n\n'
  } >> "$tmp_context"
done

file_list="$(printf '%s\n' "${normalized_files[@]}")"
file_context="$(cat "$tmp_context")"

prompt="$(cat <<EOF
You are DeepSeek running a bounded file-scoped implementation assignment delegated by Codex.

Task:
$task

Files you may modify:
$file_list

Hard boundaries:
- Codex is the orchestrator. You are a single delegate.
- Do not call Claude, Gemini, Kimi, GLM, DeepSeek, MiniMax, Perplexity, Codex, or any other agent.
- Do not request, inspect, summarize, quote, create, modify, move, or delete .codex, .claude, CLAUDE.md, AGENTS.md, or agent config files.
- Modify only the listed files. Do not add new files unless a listed file is explicitly a new path and the task requires it.
- Keep the change minimal and directly tied to the task.
- Return only a unified diff that can be applied with git apply.
- If you cannot safely produce a patch, return exactly: NO_PATCH: <reason>

Current file contents:
$file_context
EOF
)"

base_url="${DEEPSEEK_BASE_URL:-https://api.deepseek.com}"
endpoint="${base_url%/}/chat/completions"

DELEGATE_PROVIDER_NAME="DeepSeek" \
DELEGATE_ENDPOINT="$endpoint" \
DELEGATE_MODEL="${DEEPSEEK_EXECUTE_MODEL:-${DEEPSEEK_MODEL:-deepseek-v4-pro}}" \
DELEGATE_API_KEY="${DEEPSEEK_API_KEY}" \
DELEGATE_PROMPT="$prompt" \
DELEGATE_SYSTEM_PROMPT="You are DeepSeek in bounded patch mode. Return only unified diffs or NO_PATCH." \
"$script_dir/openai-compatible-chat.sh" > "$tmp_patch"

if grep -q '^NO_PATCH:' "$tmp_patch"; then
  cat "$tmp_patch"
  exit 65
fi

python3 - "$tmp_patch" <<'PY'
import sys

forbidden = (
    ".codex/",
    ".claude/",
    ".agents/",
    ".cursor/",
    ".windsurf/",
    ".github/copilot-instructions.md",
)
forbidden_names = {
    "AGENTS.md",
    "CLAUDE.md",
    "CODEX.md",
    "GEMINI.md",
    ".cursorrules",
}

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    patch = handle.read()

if "```" in patch:
    sys.stderr.write("Error: patch contains Markdown fences; refusing to apply.\n")
    sys.exit(65)

for line in patch.splitlines():
    if not (line.startswith("--- ") or line.startswith("+++ ") or line.startswith("diff --git ")):
        continue
    parts = line.split()
    paths = parts[2:] if line.startswith("diff --git ") else parts[1:2]
    for path in paths:
        path = path.strip()
        if path == "/dev/null":
            continue
        if path.startswith("a/") or path.startswith("b/"):
            path = path[2:]
        if path in forbidden_names or any(path.startswith(prefix) for prefix in forbidden):
            sys.stderr.write(f"Error: patch touches forbidden agent config path: {path}\n")
            sys.exit(65)
PY

if [ "$apply_patch" -eq 1 ]; then
  git apply --check "$tmp_patch"
  git apply "$tmp_patch"
  printf 'Applied DeepSeek patch for task: %s\n' "$task"
else
  cat "$tmp_patch"
fi
