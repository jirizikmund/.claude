---
name: taken-over-agent-dotclaude
description: Context for the agent-dotclaude config repo handed over on 2026-06-24 — what it is and where the canonical knowledge lives
metadata: 
  node_type: memory
  type: project
  originSessionId: 2e36c61e-ff46-4c7f-a763-5c65bd74f65a
---

Na 2026-06-24 Jiří předal projekt `agent-dotclaude` (handoff byl v `~/Downloads/HANDOFF.md`) — mám ho kompletně převzít.

Je to **verzovaná globální konfigurace Claude agenta** (`~/.claude`) pro účet `agent` na vzdáleném Mac mini. Není to aplikační kód — staví se tím prostředí samostatného agenta, kterého Jiří ovládá z telefonu přes Remote Control. Architektura: dvě vrstvy git repozitářů — globální `agent-dotclaude` (tohle repo) + per-projekt vnořené `agent-dotclaude-<projekt>`.

**Kanonické znalosti žijí v repu**, ne tady (cestují tím na stroj `agent`):
- provozní instrukce → `CLAUDE.md`
- architektura, klíčová rozhodnutí (NEpřehodnocovat), stav nasazení / roadmapa → `README.md`

**Why:** Handoff jsem distiloval do těchto dvou souborů místo do paměti, protože paměť je lokální na Jiřího stroji, kdežto repo se nasazuje na `agent` účet.

**How to apply:** Než začnu na tomhle repu pracovat, čti `CLAUDE.md` + `README.md` — jsou aktuální. Repo je hotové a otestované; zbývá ho nasadit (kroky A–E v `README.md` sekci „Stav nasazení"). Drž pravidla z `CLAUDE.md` (config repo = samostatná git repa, commit přes `git -C`, žádný push do chráněných větví).
