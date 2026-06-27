---
name: feedback-keep-docs-updated
description: "Syntex app has project docs in docs/ — read docs/README.md at session start, keep the relevant doc in sync when working on a feature, and commit doc changes in a separate commit."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5b46e043-fa27-4e27-82e1-f1268d186cb6
---

Projekt Syntex mobile app má **doménově členěnou dokumentaci v `docs/`** (index = `docs/README.md`, dále `docs/features/*.md` a `docs/architecture/*.md`, šablona `docs/_TEMPLATE.md`). Při startu session čti **jen `docs/README.md`** (tenká mapa); detailní dokument otevři až při práci na dané oblasti.

**Why:** Uživatel chce dlouhodobě udržitelnou dokumentaci čitelnou pro lidi i použitelnou pro mě v dalších úkolech. Index-only čtení při startu záměrně řeší zahlcení kontextu (kontext má růst s úkolem, ne s velikostí projektu).

**How to apply:** Když pracuješ na nějaké feature, dozvíš se o ní něco nového nebo změníš její chování → **aktualizuj příslušný `docs/features/*.md` nebo `docs/architecture/*.md`** a případně řádek/stav v `docs/README.md`. **Změny v dokumentaci vždy commituj zvlášť** (samostatný commit oddělený od změn kódu) — ne ve stejném commitu jako kód. Pravidlo je zakotvené i v projektovém `CLAUDE.md` (sekce „Project Documentation"), které se načítá vždy. Viz [[feedback-never-push]].
