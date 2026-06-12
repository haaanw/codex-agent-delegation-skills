# Codex Agent Delegation

Guarded multi-agent delegation for Codex.

This repository packages a Codex plugin with a global skill that lets Codex delegate bounded work to:

- Claude for code review and bounded execution.
- Gemini for architecture critique and second opinions.
- Kimi, GLM, DeepSeek, and MiniMax for parallel architecture discussion.
- DeepSeek for explicit-file, patch-first bounded execution.
- Perplexity for current external research with citations.

Codex remains the orchestrator. Delegated agents must not call other agents and must not inspect or modify `.codex`, `.claude`, `CLAUDE.md`, `AGENTS.md`, or agent config files.

## Install From GitHub

After this marketplace repo is pushed to GitHub:

```bash
codex plugin marketplace add OWNER/REPO
```

Then open the Codex plugin directory, select the `Codex Agent Delegation` marketplace, and install `Codex Agent Delegation`.

## Use

In Codex, invoke the skill directly:

```text
$codex-agent-delegation run a guarded council on this implementation plan.
```

Or run scripts from a target repository:

```bash
export CODEX_AGENT_DELEGATION="$HOME/.codex/skills/codex-agent-delegation/scripts"

"$CODEX_AGENT_DELEGATION/council.sh" "Assess this implementation plan."
"$CODEX_AGENT_DELEGATION/council.sh" --all-discuss "Assess this architecture."
"$CODEX_AGENT_DELEGATION/council.sh" --research --all-discuss "Check this API plan against current docs."
"$CODEX_AGENT_DELEGATION/deepseek-execute.sh" --file src/foo.py "Make the narrow requested change."
```

## Credentials

- Claude: `claude` CLI on `PATH`.
- Gemini: `gemini` CLI plus `GEMINI_API_KEY`, `GOOGLE_API_KEY`, or Google Cloud credentials.
- Kimi: `MOONSHOT_API_KEY` or `KIMI_API_KEY`.
- GLM/Z.ai: `ZAI_API_KEY`, `Z_AI_API_KEY`, `GLM_API_KEY`, or `ZHIPUAI_API_KEY`.
- DeepSeek: `DEEPSEEK_API_KEY`.
- MiniMax: `MINIMAX_API_KEY`.
- Perplexity: `PERPLEXITY_API_KEY`.

## Layout

```text
marketplace.json
plugins/codex-agent-delegation/
  .codex-plugin/plugin.json
  skills/codex-agent-delegation/
    SKILL.md
    agents/openai.yaml
    scripts/
```

## Official References

- Codex skills are reusable workflow packages with `SKILL.md`.
- Codex plugins are the installable distribution unit for reusable skills.
- Marketplace sources let Codex install plugins from a local folder or GitHub repo.
