---
name: Checklist knowledge reference
description: Odkaz na kompletní dokumentaci checklistové logiky v docs/guides/scheduling/checklist/
type: reference
---

Kompletní dokumentace checklistové logiky je v `docs/guides/scheduling/checklist/`:

- `README.md` — přehled systému, 3 úrovně logiky, seznam všech 18 položek, strom souborů
- `01-visibility.md` — Level 1: kdy se položka zobrazí (EU/non-EU, fuel type, international, country permit)
- `02-default-state.md` — Level 2: minimalizovaná vs. rozbalená (FLAG_LIMITS, requestPeriodDays, EarlySlot)
- `03-flag-logic.md` — Level 3: error/warning/valid mechanismus (liveFlags, REQ_LOGIC, auto-validace)
- `04-items-reference.md` — kompletní tabulky pro KAŽDOU z 18 položek
- `05-confirmation-lifecycle.md` — stavy potvrzení, reset logika při změně letiště/crew
- `06-special-cases.md` — LKPR noční lety, France/Schengen, EarlySlotWaitingList, tolerance

**Klíčové zdrojové soubory:**
- `ChecklistTable/utils/getChecklistKeys.ts` — visibility
- `ChecklistTable/utils/isServiceNotRequired.ts` — default state + FLAG_LIMITS
- `ChecklistTable/utils/createEventFlagForChecklistTab.ts` — flag logika (hlavní soubor)
- `ChecklistTable/utils/REQ_LOGIC.ts` — requested escalace
- `ChecklistTable/utils/getChecklistLastConfirmation.ts` — reset logika

Screenshoty: `memory/screenshots/checklist-*.png`
