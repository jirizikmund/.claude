---
name: "#1057 Permit checklist tab"
description: Nový Permit tab v checklistu rezervace — implementace dokončena, visibility EU/non-EU, flag logika s permitRequestPeriodDays
type: project
---

**Status:** Implementováno (commit `4be501831`)

Nový tab "Permit" v checklistu rezervace pro country permits.

**Co bylo implementováno:**
- Visibility: `isCountryPermitVisible()` — závisí na country.permitEU / permit3rdCountry + permitRequiredForFlights
- Flag logika: permitRequestPeriodDays (default 7d), permitToleranceHours (default 2h), REQ_LOGIC escalace
- PermitTab.tsx s country notes nad formulářem
- REQ_LOGIC opravena — nový `relevantEventTime` parametr pro správný čas u arrival směru

**Klíčové soubory:**
- `ChecklistTable/Tabs/PermitTab.tsx` — komponenta
- `ChecklistTable/utils/getChecklistKeys.ts` — `isCountryPermitVisible()`
- `ChecklistTable/utils/createEventFlagForChecklistTab.ts` — countryPermit sekce
- `ChecklistTable/utils/REQ_LOGIC.ts` — přidán `relevantEventTime` parametr
