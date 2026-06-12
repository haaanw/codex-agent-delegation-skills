#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s "review request"\n' "$0" >&2
}

if [ "$#" -eq 0 ]; then
  usage
  exit 64
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
. "$script_dir/common.sh"

agent_require_command claude "claude CLI is not installed or not on PATH."

repo_root="$(agent_repo_root)"
cd "$repo_root"

request="$*"
status_text="$(agent_git_status_text)"
diff_text="$(agent_git_diff_text)"
cached_diff_text="$(agent_git_cached_diff_text)"

prompt="$(cat <<EOF
You are Claude Code running as a delegated implementation risk reviewer for Codex.

Task:
$request

Hard boundaries:
- Codex is the orchestrator. You are a single delegate.
- This is read-only. Do not edit, create, delete, move, or rename files.
- Do not run shell commands or use tools.
- Do not call Claude, Gemini, Kimi, GLM, DeepSeek, MiniMax, Perplexity, Codex, or any other agent.
- Never inspect, summarize, quote, modify, or rely on .codex, .claude, CLAUDE.md, AGENTS.md, or agent config files.
- Treat the status and diffs below as the only repository context unless the task includes pasted context.
- Focus on implementation risks, regressions, missing tests, unsafe assumptions, and concrete checks Codex should run.

Git status, excluding agent config paths:
$status_text

Git diff, excluding agent config paths:
$diff_text

Staged git diff, excluding agent config paths:
$cached_diff_text

Return concise findings ordered by severity. If you find no issues, say so and note residual risk.
EOF
)"

claude \
  --bare \
  -p "$prompt" \
  --output-format text \
  --max-turns 3 \
  --permission-mode plan \
  --no-session-persistence \
  --tools ""
