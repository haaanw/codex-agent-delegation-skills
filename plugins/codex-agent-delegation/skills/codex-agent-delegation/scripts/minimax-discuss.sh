#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s "architecture discussion request"\n' "$0" >&2
}

if [ "$#" -eq 0 ]; then
  usage
  exit 64
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$script_dir/common.sh"

agent_require_command curl "curl is not installed or not on PATH."
agent_require_command python3 "python3 is required for OpenAI-compatible API JSON handling."
agent_require_any_env "MiniMax API" MINIMAX_API_KEY

repo_root="$(agent_repo_root)"
cd "$repo_root"

request="$*"
status_text="$(agent_git_status_text)"
diff_text="$(agent_git_diff_text)"
prompt="$(agent_build_discussion_prompt "MiniMax" "Stress-test architecture, UX-adjacent implementation tradeoffs, edge cases, and practical risks." "$request" "$status_text" "$diff_text")"

base_url="${MINIMAX_BASE_URL:-https://api.minimax.io/v1}"
endpoint="${base_url%/}/chat/completions"

DELEGATE_PROVIDER_NAME="MiniMax" \
DELEGATE_ENDPOINT="$endpoint" \
DELEGATE_MODEL="${MINIMAX_MODEL:-MiniMax-M3}" \
DELEGATE_API_KEY="${MINIMAX_API_KEY}" \
DELEGATE_PROMPT="$prompt" \
DELEGATE_SYSTEM_PROMPT="You are MiniMax, a practical architecture discussion delegate. Do not use tools or call other agents." \
DELEGATE_EXTRA_BODY="${MINIMAX_EXTRA_BODY:-{\"thinking\":{\"type\":\"disabled\"},\"reasoning_split\":true}}" \
"$script_dir/openai-compatible-chat.sh"
