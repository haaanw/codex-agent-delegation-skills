#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: $0 [--research] [--kimi] [--glm] [--deepseek] [--minimax] [--all-discuss] "task"

Default council runs Gemini architecture critique and Claude implementation risk review.
Additional discussion agents are opt-in.
EOF
}

research=0
use_kimi=0
use_glm=0
use_deepseek=0
use_minimax=0
args=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --research)
      research=1
      shift
      ;;
    --kimi)
      use_kimi=1
      shift
      ;;
    --glm)
      use_glm=1
      shift
      ;;
    --deepseek)
      use_deepseek=1
      shift
      ;;
    --minimax)
      use_minimax=1
      shift
      ;;
    --all-discuss)
      use_kimi=1
      use_glm=1
      use_deepseek=1
      use_minimax=1
      shift
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

if [ "${#args[@]}" -eq 0 ]; then
  usage
  exit 64
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$script_dir/common.sh"

repo_root="$(agent_repo_root)"
cd "$repo_root"

task="${args[*]}"

require_script() {
  local name="$1"
  if [ ! -x "$script_dir/$name" ]; then
    printf 'Error: missing executable %s\n' "$script_dir/$name" >&2
    exit 127
  fi
}

require_script gemini-discuss.sh
require_script claude-review.sh

agent_require_command gemini "gemini CLI is not installed or not on PATH."
agent_require_command claude "claude CLI is not installed or not on PATH."

has_gemini_key=0
if [ -n "${GEMINI_API_KEY:-}" ] || [ -n "${GOOGLE_API_KEY:-}" ]; then
  has_gemini_key=1
elif [ -n "${GOOGLE_CLOUD_PROJECT:-}" ] && [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
  has_gemini_key=1
fi

if [ "$has_gemini_key" -ne 1 ]; then
  printf 'Error: gemini CLI is installed, but no supported Gemini API credential is exported.\n' >&2
  printf 'Set GEMINI_API_KEY, GOOGLE_API_KEY, or GOOGLE_CLOUD_PROJECT plus GOOGLE_APPLICATION_CREDENTIALS.\n' >&2
  exit 78
fi

if [ "$research" -eq 1 ]; then
  require_script perplexity-research.sh
  agent_require_any_env "Perplexity API" PERPLEXITY_API_KEY
  agent_require_command curl "curl is not installed or not on PATH."
  agent_require_command python3 "python3 is required for Perplexity API JSON handling."
fi

if [ "$use_kimi" -eq 1 ]; then
  require_script kimi-discuss.sh
  agent_require_any_env "Kimi/Moonshot API" MOONSHOT_API_KEY KIMI_API_KEY
fi

if [ "$use_glm" -eq 1 ]; then
  require_script glm-discuss.sh
  agent_require_any_env "GLM/Z.ai API" ZAI_API_KEY Z_AI_API_KEY GLM_API_KEY ZHIPUAI_API_KEY
fi

if [ "$use_deepseek" -eq 1 ]; then
  require_script deepseek-discuss.sh
  agent_require_any_env "DeepSeek API" DEEPSEEK_API_KEY
fi

if [ "$use_minimax" -eq 1 ]; then
  require_script minimax-discuss.sh
  agent_require_any_env "MiniMax API" MINIMAX_API_KEY
fi

if [ "$use_kimi" -eq 1 ] || [ "$use_glm" -eq 1 ] || [ "$use_deepseek" -eq 1 ] || [ "$use_minimax" -eq 1 ]; then
  agent_require_command curl "curl is not installed or not on PATH."
  agent_require_command python3 "python3 is required for OpenAI-compatible API JSON handling."
fi

timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"
run_dir=".codex/runs/$timestamp"
if [ -e "$run_dir" ]; then
  run_dir=".codex/runs/${timestamp}-$$"
fi

mkdir -p "$run_dir"
printf '%s\n' "$task" > "$run_dir/task.txt"

{
  printf '# Agent Council Run\n\n'
  printf '- Timestamp: `%s`\n' "$timestamp"
  printf '- Task file: `task.txt`\n'
  printf '- Gemini output: `gemini-architecture.md`\n'
  printf '- Claude output: `claude-risk-review.md`\n'
  if [ "$use_kimi" -eq 1 ]; then printf '- Kimi output: `kimi-discussion.md`\n'; fi
  if [ "$use_glm" -eq 1 ]; then printf '- GLM output: `glm-discussion.md`\n'; fi
  if [ "$use_deepseek" -eq 1 ]; then printf '- DeepSeek output: `deepseek-discussion.md`\n'; fi
  if [ "$use_minimax" -eq 1 ]; then printf '- MiniMax output: `minimax-discussion.md`\n'; fi
  if [ "$research" -eq 1 ]; then printf '- Perplexity output: `perplexity-research.md`\n'; fi
} > "$run_dir/README.md"

printf 'Writing council outputs to %s\n' "$run_dir" >&2

printf 'Running Gemini architecture critique...\n' >&2
"$script_dir/gemini-discuss.sh" "Architecture critique for this task: $task" > "$run_dir/gemini-architecture.md"

if [ "$use_kimi" -eq 1 ]; then
  printf 'Running Kimi discussion...\n' >&2
  "$script_dir/kimi-discuss.sh" "Coding-oriented second opinion for this task: $task" > "$run_dir/kimi-discussion.md"
fi

if [ "$use_glm" -eq 1 ]; then
  printf 'Running GLM discussion...\n' >&2
  "$script_dir/glm-discuss.sh" "Architecture and edge-case critique for this task: $task" > "$run_dir/glm-discussion.md"
fi

if [ "$use_deepseek" -eq 1 ]; then
  printf 'Running DeepSeek discussion...\n' >&2
  "$script_dir/deepseek-discuss.sh" "Algorithmic and implementation-risk critique for this task: $task" > "$run_dir/deepseek-discussion.md"
fi

if [ "$use_minimax" -eq 1 ]; then
  printf 'Running MiniMax discussion...\n' >&2
  "$script_dir/minimax-discuss.sh" "Practical architecture stress test for this task: $task" > "$run_dir/minimax-discussion.md"
fi

printf 'Running Claude implementation risk review...\n' >&2
"$script_dir/claude-review.sh" "Implementation risk review for this task: $task" > "$run_dir/claude-risk-review.md"

if [ "$research" -eq 1 ]; then
  printf 'Running Perplexity external research...\n' >&2
  "$script_dir/perplexity-research.sh" "Current external research for this task: $task" > "$run_dir/perplexity-research.md"
fi

printf 'Council run complete: %s\n' "$run_dir"
