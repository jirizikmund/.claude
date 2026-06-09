---
name: Roster status display in calendar (#2535)
description: Implementace zobrazení ROFF, OFF, STANDBY, crew overlay a NO SCHEDULED CREW v scheduling kalendáři
type: project
---

## Zadání od klienta (Alpha Aviation, Marek Babic, 31.3.2026)

1. **U LETADLA** — průhledná vrstva v daném dni s textem "PIC/FO: Příjmení / Příjmení" (crew z rosteringu)
2. **U PILOTŮ standby** — barevný proužek (very light blue) přes celý den, text "Standby PIC OK-AML" (služba, funkce, registrace)
3. **OFF/Planned OFF u pilotů** — šedý pruh jako ROFF, ale ne červený, text "OFF"
4. **Letadlo bez crew** — červený nápis "NO SCHEDULED CREW" bez barevného zvýraznění

## Klíčový objev o datovém modelu

Standby v rosteru existuje ve dvou formách:
- **Standalone**: `relationType: 'standby'`, `aircraftId: ''` — nemá roli ani letadlo
- **S přiřazením**: `relationType: 'cpt'/'fo'`, `contactFallbackRelation.relationType: 'standby'` — má roli I letadlo

Aktuální kód zachytává obě formy.

## Rozhodnutí

- **NO SCHEDULED CREW**: zobrazit vždy když chybí crew (i při maintenance/owner_block)
- **Standalone standby** (bez letadla/role): zobrazit jen "Standby"
- Non-pilot contactIds (maintenance, owner_block, sales_block...) se filtrují přes `Object.values(RosterRelationType)`

## Implementované změny

### Soubory
- `getRosterStatusItems.ts` — hlavní logika: rozšířeno o aircraft groups, crew overlay, NO SCHEDULED CREW, enriched standby labels, filtrování non-pilot contactIds
- `useTimelineData.tsx` — předání aircraftGroups, className `group-aircraft` na aircraft groups
- `styles.sass` — CSS pro roster-aircraft-crew, roster-no-crew, top:0 pro eventy v aircraft řádcích
- `types.ts` — rozšíření rosterStatusType o 'aircraft_standby' | 'no_crew'

### Vizuální parametry
- Výška aircraft řádků: řízena inline `height: 96px !important` na background items
- Eventy přilepené k hornímu okraji: CSS `top: 0px !important` na `.vis-group.group-aircraft > .vis-item.vis-range`
- PIC/FO text: příjmení (lastName), u spodního okraje řádku
- OFF (POFF): šedé pozadí `rgba(200,200,200,0.25)`, text #333333
- STANDBY: modré pozadí `rgba(173,216,230,0.25)`, celý den (ne 08:00-20:00)

## Stav

- ROFF: funguje ✓ (vizuálně ověřeno)
- OFF (POFF): implementováno ✓ (neověřeno — chybí testovací data)
- STANDBY u pilota: implementováno ✓ (neověřeno — chybí testovací data v rosteru)
- Crew overlay u letadel: funguje ✓ (vizuálně ověřeno)
- NO SCHEDULED CREW: funguje ✓ (vizuálně ověřeno)

**Why:** Klient potřebuje vidět rostering přiřazení přímo v scheduling kalendáři pro lepší operativní přehled.

**How to apply:** Při dalších úpravách kalendáře brát v úvahu rozšířenou logiku v getRosterStatusItems.ts a CSS v styles.sass pro aircraft/pilot groups.
