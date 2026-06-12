---
name: "codex-agent-delegation"
description: "Delegate bounded work from Codex to Claude, Gemini, Kimi, GLM, DeepSeek, MiniMax, and Perplexity through guarded local scripts. Use when the user asks for an agent council, Claude review or execution, Gemini/Kimi/GLM/DeepSeek/MiniMax architecture discussion, Perplexity research with citations, or multi-agent second opinions."
---

# Codex Agent Delegation

Codex remains the orchestrator. Use this skill only when the user asks for delegation, an agent council, a second-model review, architecture discussion, current external research, or bounded execution by Claude/DeepSeek.

## Setup

Set the skill script path once:

```bash
export CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
export CODEX_AGENT_DELEGATION="$CODEX_HOME/skills/codex-agent-delegation/scripts"
```

Run scripts from the target repository. Each script resolves the repo root with `git rev-parse --show-toplevel` and falls back to `pwd`.

## Commands

Review implementation risk with Claude:

```bash
"$CODEX_AGENT_DELEGATION/claude-review.sh" "Review the current implementation risk."
```

Execute a bounded assignment with Claude:

```bash
"$CODEX_AGENT_DELEGATION/claude-execute.sh" "Add tests for X. Do not change production code unless necessary."
```

Discuss architecture, edge cases, and tradeoffs:

```bash
"$CODEX_AGENT_DELEGATION/gemini-discuss.sh" "Critique this architecture."
"$CODEX_AGENT_DELEGATION/kimi-discuss.sh" "Give a coding-oriented second opinion."
"$CODEX_AGENT_DELEGATION/glm-discuss.sh" "Find edge cases and tradeoffs."
"$CODEX_AGENT_DELEGATION/deepseek-discuss.sh" "Review algorithmic risks."
"$CODEX_AGENT_DELEGATION/minimax-discuss.sh" "Stress-test the design."
```

Gather current external information with citations:

```bash
"$CODEX_AGENT_DELEGATION/perplexity-research.sh" "Research current API behavior and cite sources."
```

Run a council:

```bash
"$CODEX_AGENT_DELEGATION/council.sh" "Assess this implementation plan."
"$CODEX_AGENT_DELEGATION/council.sh" --research --all-discuss "Assess this API integration against current docs."
```

Ask DeepSeek to prepare a bounded patch for explicit files:

```bash
"$CODEX_AGENT_DELEGATION/deepseek-execute.sh" --file src/foo.py --file tests/test_foo.py "Add tests for foo."
```

Use `--apply` only when the user explicitly approves applying DeepSeek's generated patch:

```bash
"$CODEX_AGENT_DELEGATION/deepseek-execute.sh" --apply --file src/foo.py "Make the narrow requested change."
```

## Credentials

- Claude: `claude` CLI on `PATH`.
- Gemini: `gemini` CLI plus `GEMINI_API_KEY`, `GOOGLE_API_KEY`, or `GOOGLE_CLOUD_PROJECT` with `GOOGLE_APPLICATION_CREDENTIALS`.
- Kimi: `MOONSHOT_API_KEY` or `KIMI_API_KEY`; override `KIMI_MODEL` or `KIMI_BASE_URL` if needed.
- GLM/Z.ai: `ZAI_API_KEY`, `Z_AI_API_KEY`, `GLM_API_KEY`, or `ZHIPUAI_API_KEY`; override `GLM_MODEL` or `GLM_BASE_URL` if needed.
- DeepSeek: `DEEPSEEK_API_KEY`; override `DEEPSEEK_MODEL` or `DEEPSEEK_BASE_URL` if needed.
- MiniMax: `MINIMAX_API_KEY`; override `MINIMAX_MODEL` or `MINIMAX_BASE_URL` if needed.
- Perplexity: `PERPLEXITY_API_KEY`; override `PERPLEXITY_MODEL` if needed.

## Guardrails

- No delegated agent may call another agent.
- No delegated agent may inspect, summarize, quote, create, modify, move, or delete `.codex`, `.claude`, `CLAUDE.md`, `AGENTS.md`, or other agent config files.
- Discussion agents receive only sanitized status/diff context and the task string.
- Perplexity is only for current external research and must return citations.
- Claude may edit normal project files only in bounded execute mode.
- DeepSeek execute is file-scoped and patch-based. Prefer review-before-apply.
