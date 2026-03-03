# (#1057) Nový checklist tab "Permit" pro country permits

**Status:** Plán schválen, čeká na implementaci
**Navazuje na:** #2264 (Airports/Country Notes záložky)

## Požadavky

- Nový tab "Permit" v checklistu rezervace
- Formulář jako SLOT/PPR: Time, Number, Note + akční tlačítka
- Nad formulářem readonly country notes (formát jako DISP NTS)
- Zobrazovat pro DEPARTURE i ARRIVAL
- Pořadí: za FPL
- Podmínky zobrazení (EU/non-EU) a FLAG_LIMITS budou doplněny později, zatím zobrazovat vždy

## Klíčové soubory ke změně

| Soubor | Změna |
|--------|-------|
| `@eflight/shared/.../scheduling/types/index.ts` | `countryPermit` do Checklist typu |
| `src/Admin/Scheduling/model/SchedulingTypes.ts` | ExtraKey, extraKeys, ordering |
| `ChecklistTable/utils/getChecklistTabName.ts` | Mapování 'Permit' |
| `ChecklistTable/utils/getChecklistKeys.ts` | Logika zobrazení (vždy) |
| `ChecklistTable/utils/getDefaultChecklistTime.ts` | Default time |
| **`ChecklistTable/Tabs/PermitTab.tsx`** | NOVÝ — komponenta tabu |
| `ChecklistTable/index.tsx` | Registrace PermitTab |
| `ChecklistTable/utils/createEventFlagForChecklistTab.ts` | Requested logika |

## Reuse

- `getCachedCountry(icao)` z `src/Admin/Countries/Datasources/Countries.ts` — pro načtení country
- `RichTextEditorHtmlOutput` z `src/components/RichTextEditor/` — pro readonly country notes
- `ServiceTab.tsx` jako vzor pro formulář

## Znalosti

- Viz [checklist-knowledge.md](checklist-knowledge.md) pro kompletní znalosti o checklistu
- Screenshoty v `memory/screenshots/checklist-*.png`
- Detailní plán v `/Users/jiri/.claude/plans/sprightly-hugging-penguin.md`
