---
name: 2698-fpl-unpair-implementation
description: "FPL odpárování (#2698) — HOTOVO, commit f13d8d36c. Unpair tlačítko, auto-unpair hook v ChecklistTable, async serializace, autopair rules modal. Pravidla chování + architektonická rozhodnutí a jejich důvody."
metadata:
  node_type: memory
  type: project
  originSessionId: 507176ec-a2ba-40c8-85c9-91c10468caf6
---

# #2698 FPL — možnost odpárování

**Status:** HOTOVO. Commitnuto v `f13d8d36c (#2698) Add FPL unpair option and autopair rules`, PR vytvořen. Lint/tsc/prettier čisté.

Souvisí s [[2640-live-flight-updates]] — po unpair se bar legu v kalendáři vrátí na scheduled pozici (Lambda `FlightboardProcessor` přestane párovat FPL/CTOT na leg bez `rocketRouteId`).

## Co bylo dodáno

1. Tlačítko **"Unpair FPL"** (`btn-outline-danger`) ve `FlightPlanDetail.tsx` vedle "Choose Different FPL".
2. **Auto-unpair** scénáře (hook `useFplAutoUnpair`): posun `dateFrom` mimo okno FPL, FPL cancelled.
3. **Zpřísněné auto-pair** podmínky pro `active` FPL (`isAutoPairEligible` v `RocketRouteSelector`).
4. Help modal **"FPL autopair rules"** (`FplAutopairRulesModal.tsx`) — tlačítko vedle "Checklist rules" v `Checklist/index.tsx`.

## Pravidla chování (schválená specifikace)

| # | Scénář | Akce |
|---|---|---|
| 1 | Klik "Unpair FPL" | `rocketRouteId → undefined`, `flightPlanData → undefined`, checklist confirmation `flightPlan` → `not_confirmed`. V aktuální session NESPUSTIT auto-pair. |
| 2 | Znovu-otevření rezervace bez `rocketRouteId` | Auto-pair se spustí, ale jen pokud splní pravidlo 4 (session flag se ztratí remount-em). |
| 3 | Uživatel **mění** `dateFrom` tak, že EOBT vypadne z okna `[dateFrom, dateFrom+1h]` | Auto-unpair. Platí pro posun dřív I později. NESPOUŠTĚT při pouhém otevření rezervace, jen při skutečné změně. |
| 4 | Zpřísněné auto-pair podmínky (pro `active`) | registrace letadla match (no fallback), `adepIcao === location` (ne ZZZZ), `adesIcao === locationEnd`, `eobt ∈ [dateFrom, dateFrom+1h]`, `status === 'active'`. |
| 5 | `FPL.status → 'cancelled'` | Auto-unpair. Spustí se vždy, i hned po otevření rezervace (zrušený FPL není ruční změna uživatele). |
| 6 | Manuální výběr FPL | Drží se, dokud nenastane 3) ani 5) — i pokud nesplňuje 4). |

**Draft FPL:** zachovává původní scoring ≥ 23 (`createFlightPlanScorerForEvent`). Auto-unpair se pro draft NEspouští — zpřísněná pravidla 4 platí jen pro `active`.

**"Let se vrátí kde byl"** = jen vizuálně v kalendáři. `dateFrom/dateTo` legu se NEmění.

**ZZZZ** = ICAO placeholder pro letiště bez vlastního ICAO kódu — auto-pair ho odmítá.

## Architektura — klíčová rozhodnutí a JEJICH DŮVODY

### Auto-unpair logika žije v `ChecklistTable`, ne v checklist tabu
Hook `useFplAutoUnpair` se volá z `ChecklistTable/index.tsx` (stabilní komponenta). NESMÍ žít ve `FlightPlanDetail`/`FlightPlanRocketRouteTab`, protože `@mui/joy` `TabPanel` UNMOUNTUJE neaktivní children (`children: !hidden && children`). Kdyby tam useEffecty byly, neběžely by v okamžiku, kdy uživatel mění `dateFrom` na jiné záložce checklistu. (Původní plán měl useEffecty ve `FlightPlanDetail` — chyba odhalená při code review jako V3.)

### Session flag `fplUnpairedThisSession` v `ChecklistTable`
`useState` v `ChecklistTable/index.tsx`, předává se do `ServiceTab`/`PermitTab` jako `fplUnpairedThisSession` + `onFplUnpairedChange`, dál do FPL tabu. Původní plán měl flag ve `FlightPlanRocketRouteTab` — ztrácel se při přepnutí záložky (TabPanel unmount), nález V2. Flag zaniká až při zavření celého checklistu/rezervace → tím přirozeně splňuje pravidlo 2 (re-open spustí auto-pair).

### `unpairFlightPlan` je async — serializace kvůli race condition
Helper `unpairFlightPlan.ts` musí `await onConfirm` jako PRVNÍ a teprve na výsledku (`res.ok ? res.data : childEvent`) aplikovat `rocketRouteId: undefined, flightPlanData: undefined` přes `onEventChange`. Kdyby volal `onEventChange` + `onConfirm` synchronně (jak měl původní plán), `confirmChecklist` (immer `produce`) by pracoval se zastaralým snapshotem childEventu a přepsal by první mutaci. Nález K1, opraveno serializací. Signatura: `{ childEvent, onEventChange, onConfirm }`, checklistKey hardcoded `'flightPlan'`, `data: undefined`.

### Typy onConfirm
`OnChecklistConfirm` (plné params: childEvent, direction, allChecklistKeys, airportDetail, …) vs `OnConfirmInternal` (subset: `checklistKey`, `status`, `data`) — `OnConfirmInternal` je exportován z `ChecklistTable/index.tsx`. `ChecklistTable` interně wrapuje plný `props.onConfirm` do `OnConfirmInternal` useCallbacku, který doplní childEvent/direction/atd.

## Soubory

**Nové:**
- `.../FlightPlanRocketRoute/useFplAutoUnpair.ts` — hook, auto-unpair scénáře 3 a 5
- `.../FlightPlanRocketRoute/unpairFlightPlan.ts` — async helper
- `.../FlightPlanRocketRoute/FplAutopairRulesModal.tsx` — help modal (Dialog `size: 'md'`, 5 sekcí)

**Upravené:**
- `.../FlightPlanRocketRoute/FlightPlanDetail.tsx` — "Unpair FPL" tlačítko, props `onConfirm`/`onUnpair`
- `.../FlightPlanRocketRoute/FlightPlanRocketRouteTab.tsx` — propagace props, reset session flagu při ručním výběru FPL
- `.../FlightPlanRocketRoute/RocketRouteSelector.tsx` — `isAutoPairEligible`, export konstanty `AUTO_PAIR_EOBT_WINDOW_MS` (= `60 * 60_000`), prop `disableAutoSelect`
- `.../FlightPlanRocketRoute/FlightPlanAutoConfirmer.tsx` — skrytí badge "State was automatically changed" po unpair (`fplId === undefined && prevFplId !== undefined`)
- `.../Checklist/ChecklistTable/index.tsx` — `fplUnpairedThisSession` state, volání `useFplAutoUnpair`, export `OnConfirmInternal`
- `.../ChecklistTable/Tabs/ServiceTab.tsx`, `Tabs/PermitTab.tsx` — props `onConfirm: OnConfirmInternal`, `fplUnpairedThisSession`, `onFplUnpairedChange`
- `.../Checklist/index.tsx` — tlačítko "FPL autopair rules" + `FplAutopairRulesModal`

Bázová cesta: `src/Admin/Scheduling/screen/Calendar/ReservationForm/ChildEventForm/Checklist/`

## Implementační detaily

### isAutoPairEligible (RocketRouteSelector)
- registrace letadla přesný match — bere se z `childEvent.resources` aircraft resource `.title`, žádný fallback (klient potvrdil: párovat podle registrace, ne čísla letu)
- `adepIcao === childEvent.location` (ne ZZZZ), `adesIcao === childEvent.locationEnd`
- `status === 'active'` (draft nemůže být zeleně confirmed)
- `eobt ∈ [dateFrom, dateFrom + AUTO_PAIR_EOBT_WINDOW_MS]`

Auto-select useEffect rozlišuje `isActiveStrictMatch` (`active` + `isAutoPairEligible`) vs `isDraftLegacyMatch` (`draft` + score ≥ 23 + není remíza s druhým v pořadí).

### Auto-unpair scénáře (useFplAutoUnpair)
- **Scénář 3:** `usePrev(dateFrom.getTime())` — spustí jen při SKUTEČNÉ změně (`prevDateFromMs !== undefined && prevDateFromMs !== fromMs`), pak když `eobt` vypadne z `[fromMs, fromMs + AUTO_PAIR_EOBT_WINDOW_MS]`. Guard `direction === 'departure'`.
- **Scénář 5:** `flightplan.status === 'cancelled'`. Guard `direction === 'departure'`.

## Co tento PR NEdělá (zbývá z #2698 — další iterace)

- Rozlišení IOBT/EOBT v UI
- CDM letiště: validace `IOBT = SLOT/PPR ± 0min` (jinak červeně)
- EOBT -30/+60 min červeně
- Backend flag pro automatickou aktualizaci legu se změnou FPL

## Detailní plán

`/Users/jiri/.claude/plans/zjisti-jak-funguje-pure-petal.md` (pozn.: plán popisuje původní návrh — finální architektura se liší v umístění hooku/flagu a v async serializaci, viz výše).
