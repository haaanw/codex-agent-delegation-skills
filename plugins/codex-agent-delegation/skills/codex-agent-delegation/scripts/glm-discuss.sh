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
agent_require_any_env "GLM/Z.ai API" ZAI_API_KEY Z_AI_API_KEY GLM_API_KEY ZHIPUAI_API_KEY

repo_root="$(agent_repo_root)"
cd "$repo_root"

request="$*"
status_text="$(agent_git_status_text)"
diff_text="$(agent_git_diff_text)"
prompt="$(agent_build_discussion_prompt "GLM" "Discuss architecture, coding tradeoffs, edge cases, failure modes, and second opinions." "$request" "$status_text" "$diff_text")"

api_key="$(agent_first_env_value ZAI_API_KEY Z_AI_API_KEY GLM_API_KEY ZHIPUAI_API_KEY)"
base_url="${GLM_BASE_URL:-https://api.z.ai/api/paas/v4}"
endpoint="${base_url%/}/chat/completions"

DELEGATE_PROVIDER_NAME="GLM" \
DELEGATE_ENDPOINT="$endpoint" \
DELEGATE_MODEL="${GLM_MODEL:-glm-4.7}" \
DELEGATE_API_KEY="$api_key" \
DELEGATE_PROMPT="$prompt" \
DELEGATE_SYSTEM_PROMPT="You are GLM, a software architecture discussion delegate. Do not use tools or call other agents." \
"$script_dir/openai-compatible-chat.sh"
