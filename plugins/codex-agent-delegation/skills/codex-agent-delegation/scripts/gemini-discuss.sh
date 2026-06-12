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

agent_require_command gemini "gemini CLI is not installed or not on PATH."

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

repo_root="$(agent_repo_root)"
cd "$repo_root"

request="$*"
status_text="$(agent_git_status_text)"
diff_text="$(agent_git_diff_text)"
prompt="$(agent_build_discussion_prompt "Gemini" "Discuss architecture, edge cases, tradeoffs, assumptions, alternatives, and second opinions." "$request" "$status_text" "$diff_text")"

tmp_home="$(mktemp -d "${TMPDIR:-/tmp}/codex-gemini-home.XXXXXX")"
cleanup() {
  rm -rf "$tmp_home"
}
trap cleanup EXIT HUP INT TERM

(
  cd "$tmp_home"
  HOME="$tmp_home" \
  NO_COLOR=1 \
  GEMINI_TELEMETRY_ENABLED=false \
  gemini \
    -p "$prompt" \
    --output-format text \
    --approval-mode default \
    -e none
)
