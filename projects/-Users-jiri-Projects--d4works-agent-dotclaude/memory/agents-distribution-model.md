---
name: agents-distribution-model
description: "Jak se v agent-dotclaude distribuují subagenti — root agents/ je kanonický zdroj, instalace per-projekt"
metadata: 
  node_type: memory
  type: project
  originSessionId: 96780c39-608d-4655-9f26-9759018d6baf
---

Subagenti (`web-inspector`, `mobile-inspector`, …) žijí v repu `agent-dotclaude`
v root složce `agents/` (whitelistnuta v `.gitignore` řádkem `!/agents/`).

**Root `agents/` je kanonický ZDROJ, ne live aktivace.** Tenhle repo se vyvíjí
v `~/Projects/@d4works/agent-dotclaude` a teprve se slévá do live `~/.claude`.

- `~/.claude/agents/*.md` → globální aktivace ve VŠECH projektech.
- `<projekt>/.claude/agents/*.md` → aktivní jen v tom projektu.

**Why:** Jiří chce agenty instalovat selektivně (jen někde, jen jeden — web-inspector
→ eFlight, mobile-inspector → MTMS); jejich popisy jsou na konkrétní projekt napevno.

**How to apply:** Při nasazení repa do live `~/.claude` složku `agents/`
NEKOPÍROVAT do `~/.claude/agents/` (README deploy list `bin hooks skills templates
docs` ji schválně nezahrnuje). Instalace do projektu = `cp` souboru do
`<projekt>/.claude/agents/` + commit v jeho vnořeném repu `git -C <projekt>/.claude …`.
Cílový projekt musí mít i odpovídající MCP server (Playwright pro web, Appium pro mobil).
Viz [[taken-over-agent-dotclaude]].
