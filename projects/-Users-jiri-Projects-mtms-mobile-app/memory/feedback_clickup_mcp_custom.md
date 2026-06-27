---
name: feedback_clickup_mcp_custom
description: "Uživatel má vlastní ClickUp MCP a preferuje ho rozšiřovat, ne připojovat oficiální mcp.clickup.com"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1faac19b-d4da-4c68-8769-26bce9477fe3
---

Projekt používá **vlastní (custom) ClickUp MCP server** (nástroje `mcp__clickup__*`), který si uživatel sám spravuje. K 2026-06-20 měl 6 nástrojů: `get-task`, `get-task-statuses`, `set-task-status`, `get-release-options`, `set-task-release`, `test-connection` — **neuměl komentáře**.

Oficiální `https://mcp.clickup.com/mcp` má ~48 nástrojů (vč. Get/Create Task Comment), ale je OAuth-only a v public beta.

Když chyběla funkce (komentáře), uživatel se rozhodl **rozšířit vlastní MCP**, ne připojovat oficiální.

**Why:** Vlastní server je laděný na jeho workflow (resolving custom ID `TMS-563`, „Release" dropdown helper, napojení na [[feedback_clockify_timer_workflow]]).

**How to apply:** Když narazím na chybějící ClickUp funkci, předpokládat rozšíření vlastního serveru. Nenavrhovat oficiální mcp.clickup.com jako řešení, pokud si o to výslovně neřekne.
