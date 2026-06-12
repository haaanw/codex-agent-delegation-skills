#!/usr/bin/env bash
set -euo pipefail

AGENT_EXCLUDED_PATHS=(
  ':(exclude).codex/**'
  ':(exclude).claude/**'
  ':(exclude).agents/**'
  ':(exclude)AGENTS.md'
  ':(exclude)CLAUDE.md'
  ':(exclude)CODEX.md'
  ':(exclude)GEMINI.md'
  ':(exclude).cursorrules'
  ':(exclude).cursor/**'
  ':(exclude).windsurf/**'
  ':(exclude).aider*'
  ':(exclude).github/copilot-instructions.md'
)

agent_repo_root() {
  local root
  if command -v git >/dev/null 2>&1 && root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf '%s\n' "$root"
  else
    pwd
  fi
}

agent_require_command() {
  local cmd="$1"
  local message="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf 'Error: %s\n' "$message" >&2
    exit 127
  fi
}

agent_first_env_value() {
  local name value
  for name in "$@"; do
    eval "value=\${${name}:-}"
    if [ -n "$value" ]; then
      printf '%s\n' "$value"
      return 0
    fi
  done
  return 1
}

agent_require_any_env() {
  local label="$1"
  shift
  if ! agent_first_env_value "$@" >/dev/null; then
    printf 'Error: no %s credential is exported. Set one of: %s\n' "$label" "$*" >&2
    exit 78
  fi
}

agent_git_status_text() {
  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git status --short -- . "${AGENT_EXCLUDED_PATHS[@]}"
  else
    printf 'Not a git repository; no git status available.\n'
  fi
}

agent_git_diff_text() {
  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git diff --no-ext-diff -- . "${AGENT_EXCLUDED_PATHS[@]}"
  else
    printf 'Not a git repository; no git diff available.\n'
  fi
}

agent_git_cached_diff_text() {
  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git diff --cached --no-ext-diff -- . "${AGENT_EXCLUDED_PATHS[@]}" 2>/dev/null || true
  else
    printf 'Not a git repository; no staged git diff available.\n'
  fi
}

agent_forbidden_path() {
  local path="${1#./}"
  case "$path" in
    .codex|.codex/*|*/.codex|*/.codex/*|\
    .claude|.claude/*|*/.claude|*/.claude/*|\
    .agents|.agents/*|*/.agents|*/.agents/*|\
    AGENTS.md|*/AGENTS.md|CLAUDE.md|*/CLAUDE.md|CODEX.md|*/CODEX.md|GEMINI.md|*/GEMINI.md|\
    .cursorrules|*/.cursorrules|.cursor|.cursor/*|*/.cursor|*/.cursor/*|\
    .windsurf|.windsurf/*|*/.windsurf|*/.windsurf/*|\
    .aider*|*/.aider*|.github/copilot-instructions.md|*/.github/copilot-instructions.md)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

agent_normalize_repo_path() {
  local repo_root="$1"
  local raw_path="$2"
  python3 - "$repo_root" "$raw_path" <<'PY'
import os
import sys

repo = os.path.realpath(sys.argv[1])
path = os.path.realpath(os.path.join(repo, sys.argv[2]))

try:
    common = os.path.commonpath([repo, path])
except ValueError:
    sys.exit(2)

if common != repo:
    sys.exit(2)

print(os.path.relpath(path, repo))
PY
}

agent_build_discussion_prompt() {
  local agent_name="$1"
  local role_line="$2"
  local request="$3"
  local status_text="$4"
  local diff_text="$5"
  cat <<EOF
You are $agent_name running as a delegated discussion agent for Codex.

Task:
$request

Hard boundaries:
- Codex is the orchestrator. You are a single delegate.
- $role_line
- Do not execute implementation work.
- Do not call Claude, Gemini, Kimi, GLM, DeepSeek, MiniMax, Perplexity, Codex, or any other agent.
- Do not inspect, request, list, read, summarize, quote, modify, create, move, or delete .codex, .claude, CLAUDE.md, AGENTS.md, or agent config files.
- Use only the task text and sanitized git context below. If you need more repository context, ask Codex to provide a sanitized excerpt.

Sanitized git status, excluding agent config paths:
$status_text

Sanitized git diff, excluding agent config paths:
$diff_text

Return:
- Architecture critique or second opinion.
- Edge cases and failure modes.
- Tradeoffs and alternatives.
- Questions Codex should resolve before implementation.
EOF
}
