#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s "bounded implementation request"\n' "$0" >&2
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

disallowed_tools=(
  'Bash(*claude*)'
  'Bash(*gemini*)'
  'Bash(*kimi*)'
  'Bash(*moonshot*)'
  'Bash(*glm*)'
  'Bash(*zai*)'
  'Bash(*z.ai*)'
  'Bash(*deepseek*)'
  'Bash(*minimax*)'
  'Bash(*perplexity*)'
  'Bash(*codex*)'
  'Bash(*.codex*)'
  'Bash(*.claude*)'
  'Bash(*.agents*)'
  'Bash(*AGENTS.md*)'
  'Bash(*CLAUDE.md*)'
  'Bash(*CODEX.md*)'
  'Bash(*GEMINI.md*)'
  'Bash(*.cursorrules*)'
  'Bash(*.cursor*)'
  'Bash(*.windsurf*)'
  'Bash(*.aider*)'
  'Bash(*copilot-instructions.md*)'
  'Read(*.codex*)'
  'Read(*.claude*)'
  'Read(*.agents*)'
  'Read(*AGENTS.md*)'
  'Read(*CLAUDE.md*)'
  'Read(*CODEX.md*)'
  'Read(*GEMINI.md*)'
  'Read(*.cursorrules*)'
  'Read(*.cursor*)'
  'Read(*.windsurf*)'
  'Read(*.aider*)'
  'Read(*copilot-instructions.md*)'
  'Grep(*.codex*)'
  'Grep(*.claude*)'
  'Grep(*.agents*)'
  'Grep(*AGENTS.md*)'
  'Grep(*CLAUDE.md*)'
  'Grep(*CODEX.md*)'
  'Grep(*GEMINI.md*)'
  'Grep(*.cursorrules*)'
  'Grep(*.cursor*)'
  'Grep(*.windsurf*)'
  'Grep(*.aider*)'
  'Grep(*copilot-instructions.md*)'
  'Glob(*.codex*)'
  'Glob(*.claude*)'
  'Glob(*.agents*)'
  'Glob(*AGENTS.md*)'
  'Glob(*CLAUDE.md*)'
  'Glob(*CODEX.md*)'
  'Glob(*GEMINI.md*)'
  'Glob(*.cursorrules*)'
  'Glob(*.cursor*)'
  'Glob(*.windsurf*)'
  'Glob(*.aider*)'
  'Glob(*copilot-instructions.md*)'
  'LS(*.codex*)'
  'LS(*.claude*)'
  'LS(*.agents*)'
  'LS(*AGENTS.md*)'
  'LS(*CLAUDE.md*)'
  'LS(*CODEX.md*)'
  'LS(*GEMINI.md*)'
  'LS(*.cursorrules*)'
  'LS(*.cursor*)'
  'LS(*.windsurf*)'
  'LS(*.aider*)'
  'LS(*copilot-instructions.md*)'
  'Edit(*.codex*)'
  'Edit(*.claude*)'
  'Edit(*.agents*)'
  'Edit(*AGENTS.md*)'
  'Edit(*CLAUDE.md*)'
  'Edit(*CODEX.md*)'
  'Edit(*GEMINI.md*)'
  'Edit(*.cursorrules*)'
  'Edit(*.cursor*)'
  'Edit(*.windsurf*)'
  'Edit(*.aider*)'
  'Edit(*copilot-instructions.md*)'
  'MultiEdit(*.codex*)'
  'MultiEdit(*.claude*)'
  'MultiEdit(*.agents*)'
  'MultiEdit(*AGENTS.md*)'
  'MultiEdit(*CLAUDE.md*)'
  'MultiEdit(*CODEX.md*)'
  'MultiEdit(*GEMINI.md*)'
  'MultiEdit(*.cursorrules*)'
  'MultiEdit(*.cursor*)'
  'MultiEdit(*.windsurf*)'
  'MultiEdit(*.aider*)'
  'MultiEdit(*copilot-instructions.md*)'
  'Write(*.codex*)'
  'Write(*.claude*)'
  'Write(*.agents*)'
  'Write(*AGENTS.md*)'
  'Write(*CLAUDE.md*)'
  'Write(*CODEX.md*)'
  'Write(*GEMINI.md*)'
  'Write(*.cursorrules*)'
  'Write(*.cursor*)'
  'Write(*.windsurf*)'
  'Write(*.aider*)'
  'Write(*copilot-instructions.md*)'
  'NotebookEdit(*.codex*)'
  'NotebookEdit(*.claude*)'
  'NotebookEdit(*.agents*)'
  'NotebookEdit(*AGENTS.md*)'
  'NotebookEdit(*CLAUDE.md*)'
  'NotebookEdit(*CODEX.md*)'
  'NotebookEdit(*GEMINI.md*)'
  'NotebookEdit(*.cursorrules*)'
  'NotebookEdit(*.cursor*)'
  'NotebookEdit(*.windsurf*)'
  'NotebookEdit(*.aider*)'
  'NotebookEdit(*copilot-instructions.md*)'
)

prompt="$(cat <<EOF
You are Claude Code running a bounded implementation assignment delegated by Codex.

Task:
$request

Hard boundaries:
- Codex is the orchestrator. You are a single delegate.
- Execute only this bounded task. Do not broaden scope or start unrelated cleanup.
- You may inspect and edit normal project files needed for this task.
- Do not run shell commands. If verification requires commands, report exact commands for Codex or the user to run.
- Do not call Claude, Gemini, Kimi, GLM, DeepSeek, MiniMax, Perplexity, Codex, or any other agent.
- Never inspect, list, search, read, summarize, quote, modify, create, move, or delete .codex, .claude, CLAUDE.md, AGENTS.md, or agent config files.
- Agent config files include .agents, .cursor, .cursorrules, .windsurf, .aider*, CODEX.md, GEMINI.md, and .github/copilot-instructions.md.
- If the task requires touching an agent config path, stop and explain that the task is outside this delegate authority.
- Keep changes minimal and directly tied to the request.

When finished, report:
- What changed.
- Any verification commands that should be run.
- Any remaining risk or follow-up.
EOF
)"

claude \
  --bare \
  -p "$prompt" \
  --output-format text \
  --max-turns 8 \
  --permission-mode acceptEdits \
  --no-session-persistence \
  --tools "Read,Grep,Glob,LS,Edit,MultiEdit,Write" \
  --disallowedTools "${disallowed_tools[@]}"
