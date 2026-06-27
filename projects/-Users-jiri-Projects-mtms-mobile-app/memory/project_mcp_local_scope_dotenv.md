---
name: project_mcp_local_scope_dotenv
description: ClickUp/Clockify MCP jsou registrované v local scope a čtou .claude/.env.local přes DOTENV_CONFIG_PATH; žádný committed .mcp.json už neexistuje
metadata: 
  node_type: memory
  type: project
  originSessionId: 7394446e-62f0-412b-8d5d-cd81cea9dbac
---

Od 2026-06-27 jsou `clickup` i `clockify` MCP servery v mtms registrované v **local scope**
(`~/.claude.json` pod klíčem projektu), ne přes committed `.mcp.json` — ten byl smazán.
Registrace je generická: `npx -y @d4works/mcp-clickup@latest` + env jen
`DOTENV_CONFIG_PATH=<projekt>/.claude/.env.local`. Balíčky mají `import "dotenv/config"`,
takže si **všechny** hodnoty (token i ne-tajná ID jako `CLICKUP_TEAM_ID`,
`CLOCKIFY_WORKSPACE_ID/PROJECT_ID`, prefixy) načtou z `.env.local`.

**Why:** jediný zdroj pravdy = `.env.local`; `.mcp.json` v klientském repu nikomu kromě
majitele `.env.local` stejně nefungoval a porušoval princip „agent config mimo klientský repo".

**How to apply:** když MCP `clickup`/`clockify` v sessione chybí (čerstvý stroj / reset
`~/.claude.json`), znovu zaregistruj — NE přidávat `.mcp.json`:
`claude mcp add clickup --scope local --env DOTENV_CONFIG_PATH="$PWD/.claude/.env.local" -- npx -y @d4works/mcp-clickup@latest`
(a totéž pro clockify). `.claude/` je teď ignorované klientským repem (global
`core.excludesfile`) a je to samostatný nested repo `agent-dotclaude-mftl-mobile-app`.
Stejný vzor je zadrátovaný do `~/Projects/@d4works/agent-dotclaude/bin/init-project`.
Souvisí s [[feedback_clickup_mcp_custom]].
