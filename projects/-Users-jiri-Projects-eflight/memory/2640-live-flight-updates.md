---
name: Live flight updates v scheduling (#2640)
description: Kompletní logika živých dat (FPL/CTOT/actuals) ve scheduling kalendáři — fáze, časy, šrafa, popup, blink. Historie commitů a vědomá rozhodnutí.
type: project
originSessionId: 03918468-eab2-4b0b-a5fc-eab6cfae436d
---
# #2640 Scheduling — live flight updates

HIGH PRIORITY. Přiřazeno veproza + jirizikmund.

**Why:** Scheduling dostával z flightboardu jen `FlightStatus` enum. `CreateFlightboardDataInput.flightboardData` ale nese celý JSON `FlightInfo` (fpl, calculatedDeparture=CTOT, actualDeparture, estimatedArrival, actualArrival, source). Cíl: propagovat časy do popupu, posunu baru i do výpočtu duty normy.

## Architektura dat

- **Backend Lambda** (`amplify/backend/function/flightboard/src/FlightboardProcessor.ts`) běží na CloudWatch/EventBridge plánu:
  - `syncFlightboardData` natáhne rezervace v okně `[now − 2h, now + 24h]` a vytváří/aktualizuje `FlightboardData` záznamy (`isActive: 'x'`).
  - `archiveData` archivuje (nuluje `isActive`) flightboardy starší 2 h od `actualArrival`.
- **Frontend** (`src/Admin/Flightboard/Datasources/Flightboard.ts` + `dataStream.ts`):
  - `listFlightboardStates` GraphQL query filtruje `isActive: 'x'` (paginováno), žádný date filter na frontendu — backend kontroluje rozsah.
  - AppSync subscription (`onUpdate/onCreate/onDelete`) → realtime updaty do `dataService` (EventEmitter, singleton).
  - `getFlightInfo(reservationId, childEventId)` s `WeakMap` cache parsuje JSON `flightboardData`.
  - DEV helper `__flightboardDataService.simulateFlightInfo()` pro injektování fake `FlightInfo` z console.

**Efektivní okno živých dat: `[now − 2h post-landing, now + 24h pre-departure]`.** Leg mimo okno → `getFlightInfo()` = `undefined` → `flightInfo` undefined v `deriveEffectiveTimes` → bar zůstane na scheduled.

## Centrální logika: `src/Admin/Flightboard/models/effectiveTimes.ts`

### Konstanty

```ts
EARLY_SHIFT_TOLERANCE_MS = 15 * 60_000  // 15 min — DŘÍVE
LATE_SHIFT_TOLERANCE_MS  = 30 * 60_000  // 30 min — POZDĚJI
PLANNED_LOOKAHEAD_MS     = 24 * 3600_000 // 24 h — 24h gate
```

### `deriveEffectiveTimes(scheduledFrom, scheduledTo, flightInfo, isCancelled, now?)`

Vrací `EffectiveTimes`:
```ts
{
  effectiveTimeOut: Date,    // pozice levého okraje baru
  effectiveTimeIn: Date,     // pozice pravého okraje baru
  phase: 'cancelled' | 'scheduled' | 'planned' | 'inflight' | 'landed',
  fplTime?, ctotTime?, actualDeparture?, actualArrival?: Date,
  flightTimeMs: number,      // VŽDY scheduled duration (#2640, 2df144808)
  isShifted: boolean,        // → CSS .delayed šrafa
}
```

**Postup výpočtu:**

1. `isCancelled === true` → phase='cancelled', časy=scheduled, isShifted=false, EARLY RETURN.
2. Parse `fplTime, ctotTime, actualDeparture, actualArrival` z `flightInfo`.
3. **`flightTimeMs = scheduledTo - scheduledFrom`** (vždy scheduled duration). FPL `estimatedArrival - fpl` se ignoruje — bylo často outdated nebo nereprezentativní (RR rezerva / reroute).
4. **`effectiveTimeOut` priorita:** `actualDeparture > CTOT > FPL > scheduledFrom`.
5. **`effectiveTimeIn` priorita:** `actualArrival > effectiveTimeOut + flightTimeMs > scheduledTo`.
6. **`phase` priorita:** `actualArrival → 'landed'`, `actualDeparture → 'inflight'`, `CTOT||FPL → 'planned'`, `else → 'scheduled'`.
7. **24h gate:** pokud `phase==='planned'` a `scheduledFrom - now > 24h` → snap zpět na scheduled (časy + phase='scheduled'). FPL víc než den dopředu se ignoruje.
8. **`isShifted` (asymetrické prahy, CTOT priorita, OR dep|arr):**
   - `depShiftMs`: pro `inflight` = `actualDeparture - scheduledFrom`, pro `planned` = `(CTOT ?? FPL) - scheduledFrom`, jinak undefined.
   - `isDepShifted = depShiftMs < -15min || depShiftMs >= 30min`.
   - `isArrShifted = (planned||inflight) && (effectiveTimeIn - scheduledTo) >= 30min` (jen late, jen pre-landing).
   - `isShifted = isDepShifted || isArrShifted`. Pro landed/scheduled/cancelled vždy false.

### `getLegTimeSlots(scheduledFrom, scheduledTo, eff) → { out, in }`

Slot = `{ mode:'single', time } | { mode:'blink', sched, eff }`. Barvy single časů řeší CSS přes `phase-*` className legu.

- **scheduled/cancelled:** out/in = single(scheduledFrom/To), CSS default = černá.
- **planned + !isShifted:** out/in = single(effectiveTimeOut/In), barva = černá. Bar je posunutý, ale časy nepřeblikávají.
- **planned + isShifted:** out = blink(scheduledFrom ↔ CTOT||FPL), in = blink(scheduledTo ↔ effectiveTimeIn). CSS `phase-planned` → sched černě, eff žlutě, animace.
- **inflight:** out = single(actualDeparture, zelený přes CSS), in = single(effectiveTimeIn=ETA, černá).
- **landed:** out = single(actualDeparture), in = single(actualArrival). CSS `phase-landed` → obě zeleně.

## Renderer baru: `getItemContent.ts` + `styles.sass`

**KRITICKÉ:** vis-timeline strhává `class`/`style` z obsahu položky (xss whitelist `span:[]`, `small:[]`, `em:[]`, `u:[]`, ...). V obsahu **NELZE** používat `class=`. Barvy/blikání = strukturální CSS (`:nth-child`, element types) + className legu (`.delayed`, `.phase-planned/inflight/landed`, `.status-blink`) na `.vis-item` (nesanitizuje se) + class wrapperu (`.vis-item-resolution-width_50`).

**className na `.vis-item`:**
- `cancelled` — line-through ICAO.
- `delayed` — žlutá šrafa nad celým barem (`border-top: 3px dashed warning` na `.vis-item-overflow`). Přidává se pokud `eff?.isShifted === true && eff.phase !== 'cancelled'`.
- `phase-planned` / `phase-inflight` / `phase-landed` — barva časů v baru.
- `status-blink` — blikání status badge (pokud `getFlightStatusShouldBlink`).
- `duty-error` / `duty-warning` — barva levého proužku.

**Časy (`<small>HH:mm</small>`) viditelné jen při `width_50` (větší zoom); menší rozlišení `small { display:none }`:**
- `phase-inflight span:nth-child(1) > small` (dep): zelený actual.
- `phase-landed span:nth-child(1)/(4) > small` (dep+arr): zelené actuals.
- `phase-planned span:nth-child(1)/(4) > small { display: inline-grid }` + vnořené `<small>` (sched, černý) a `<em>` (eff, žlutý) přes sebe, blink 2s step-end. Vrací se jen pokud `isShifted` (jinak je `<small>HH:mm</small>` bez vnořeného `<em>`, vykreslí se jako default).

**Status badge (span:nth-child(5)):**
- `<u><em>{letter}</em><strong>{text}</strong></u>` uvnitř 8×`<sub>` (pozice nese variantu přes `u:nth-child(N)` v CSS, stejně jako pax/flag badges).
- Default zobrazí `<em>` (jedno písmeno); `vis-item-resolution-width_50` přepne na `<strong>` (long text, right-anchored `right: 34px`).
- Mapa: `LEG_STATUS_LABELS` v `getItemContent.ts` — P/Planned, D/DEP RDY, B/BOARDING, ✈/IN FLIGHT, A/ARR 30min, A/ARR 15min, L/LANDED, ?/MISSING, O/ON HOLD, D/DLY, S/Suspended FPL, N/NOT CLOSED, D/DIVERTED, C/Cancelled. `Schedulled` → no badge.
- Variant = `getFlightStatusVariant({ flightStatus, estimatedArrivalDate: eff?.effectiveTimeIn })` z `FlightboardStatus.tsx` (sjednoceno s flightboardem).
- Blink = `getFlightStatusShouldBlink(flightStatus)` (set: ArrivalIn15/30Minutes, DelayedDeparture, Diverted, Missing, NotClosed, Suspended).

## Popup: `LegPopupContent/index.tsx`

`Location` (levý / pravý blok letiště) zobrazuje `effLines` pod local timem:

`getEffLines(eff, side, scheduled)`:
- `cancelled` → `[]`.
- **Left** (odlet):
  - `actualDeparture` existuje → jen `[{ Departed, success }]` (zeleně). FPL/CTOT skryté po odletu (#2640, 0c63342c1).
  - Jinak: `FPL` (pokud existuje) + `CTOT` (pokud existuje), barva přes `colorForShift`.
- **Right** (přílet):
  - `actualArrival` → `[{ Landed, success }]`.
  - `planned || inflight` → `[{ ETA: effectiveTimeIn, colorForShift }]`.
  - Jinak `[]`.

`colorForShift(time, scheduled)` = `'warning'` (žluté) pokud `diff < -15min || diff >= 30min`, jinak `undefined` (default černé).

Aktuální flight time v popupu (`HH:mm`) se počítá z `childEvent.dateTo - childEvent.dateFrom` (scheduled duration) — to je info pro uživatele, ne výpočetní hodnota.

## Duty calc propagace

`childEventToFlightLegLike` (`calendarDuties.ts`) → `DutyPostprocessor.updateDataWithErrors`:
- `DutyPostprocessor` znovu odvodí `eff` z `flightInfo` před `getItemContentPropsBasedOnData`, aby se obsah baru nevracel na scheduled jen kvůli změně duty erroru (latentní bug v základním kole).

## Historie commitů (chronologicky)

| Hash | Datum | Účel |
|---|---|---|
| `7bd7e6fc6` | 4.–5. 5. | Data layer foundation: `listFlightboardStates`, `flightboardData` JSON, `deriveEffectiveTimes`, `dataService`, DEV simulate. |
| `7cdea2aae` | | Bar position by effective times. |
| `690a4e15d` | | Hover popup ETD/CTOT/Departed/Landed. |
| `afe1fd5d4` | | Duty calculation propagace (`DutyPostprocessor`). |
| `94ac5cdad` | | UX polish: 24h gate + arrival blink. |
| `4ac134116` | 12. 5. | (PR #2697) Rework leg časů a status badge + vis-timeline class-stripping workaround. |
| `1493f8ea0` | 12. 5. | Popup: ETD → FPL, FPL/CTOT do bloku letiště odletu. |
| `3873bc988` | 13. 5. | Fix: FPL/CTOT v popupu vždy zobrazeny + barva per čas. Pushnut přímo na master ⚠️ (viz `feedback_no_auto_pr`). |
| `8a5592798` | 13. 5. | (PR #2701 původní base) Žlutá šrafa nad legem jen pro FPL/CTOT posun >=15 min — **squashnuto pryč**. |
| `0c63342c1` | 13. 5. | Asymetrické prahy + CTOT priorita + skrytí FPL/CTOT po odletu — **squashnuto pryč**. |
| `2df144808` | 13. 5. | Délka letu vždy scheduled duration — **squashnuto pryč**. |
| `8c4ec0d07` | 13. 5. | (PR #2701) **SQUASH** logiky: výsledek = `8a5592798 + 0c63342c1 + 2df144808`. Force-pushnuto na origin. |
| `8e9e71484` | 13. 5. | (PR #2701) Docs: `docs/guides/scheduling/calendar/README.md` — tabulkové shrnutí faze x co se zobrazuje. |

**PR #2701** open na větvi `2640-shrafa-fpl-ctot` — 2 commity nad `3873bc988`. Force-pushnut po squashi se souhlasem uživatele 13. 5. 2026. Backup branch `backup-2640-shrafa-fpl-ctot-presquash` zachován lokálně pro případ.

## Vědomá rozhodnutí (potvrzeno uživatelem)

- **Délka letu = vždy scheduled duration.** FPL `estimatedArrival - fpl` byl občas outdated / nereprezentativní (1:44 vs 1:05 scheduled u LEMD→LEZL kvůli RR rezervě), což generovalo nesmyslné ETA `actualDep + FPL_duration`. Scheduled duration je realistický fallback. Pre-takeoff ETA = `FPL_dep + sched`; post-takeoff ETA = `actualDep + sched`.
- **Žlutá šrafa = jedna `.delayed` čára přes celý bar, OR mezi departure a arrival shift.** Žádný refaktor HTML/CSS do dvou nezávislých sekcí.
- **Bar vždy na effective time** (planned-snap zrušen v `0c63342c1`). I malé posuny (např. +5 min CTOT) viditelně posunou bar. Šrafa je nezávislá podmínka.
- **Asymetrické prahy:** `> 15 min DŘÍVE` NEBO `>= 30 min POZDĚJI`. Mezi `[-15 min, +30 min)` je leg „on time".
- **CTOT > FPL priorita** pro detekci shiftu (zrcadlí prioritu pozice baru). Pokud existuje CTOT, FPL se pro `isShifted` ignoruje.
- **Šrafa po přistání zmizí** bezpodmínečně, i kdyby TLB actuals byly hodně mimo scheduled.
- **Po odletu** v popupu vlevo jen `Departed` zeleně; FPL/CTOT řádky zmizí. Vpravo `ETA` (pre-landing) / `Landed` (post-landing) zachovány.
- **Barvy/blikání všech stavů badge** = výhradně Flightboard (`getFlightStatusVariant` + `getFlightStatusShouldBlink`).
- **TLB po přistání** — VYŘEŠENO (větev `feature/flightdata`, commit `c844c5ebc`, 29. 5. 2026). Lukáš Vlček přidal na rezervaci field `flightData: { flights: { departure, arrival, childEventId }[] }` (commit `985911cee`), který nese reálné eTLB časy kdykoliv zpětně (ne jen ~2 h). Integrováno jako **nejvyšší priorita actuals** v `deriveEffectiveTimes` (nový 5. param `flightDataTimes` před `now`): `flightData > flightboard actual > CTOT > FPL > scheduled`. Helper `ChildEventUtils.getFlightData({ childEvent, reservation })` mapuje na leg přes `childEventId`. Předáno do všech 6 call sites. POZOR: `flightData` se parsuje bez `dateTimeReviver` → časy jsou ISO stringy (řeší `toDate`). Původně plánovaný fallback přes `listLegsByReservationId` se NEdělal.

## Otevřené / k ověření

- **Drobná nekonzistence v ETA color:** `colorForShift` v popupu používá asymetrický práh dvojstranně (early > 15 OR late >= 30) pro všechny řádky včetně ETA. `isArrShifted` v `effectiveTimes` je ale jen jednostranný (late >= 30). Důsledek: ETA `−20 min` (early arrival) → žlutá v popupu, ale šrafa NE. V praxi early arrival vzácný; nemusí být problém.
- `EffectiveTimes.flightTimeMs` ve typu je nyní vždy scheduled duration. Žádný externí consumer (jen self). Lze odstranit z typu, nebo ponechat jako defensive.
- Vizuální tuning `width_50` `.leg-status-text` right-anchor a blink-grid sizing (`right:34px`).
- Koordinace s @veproza ohledně konzumentů normy mimo scheduling kalendář.
- Historický leg s `flightData` → `phase='landed'` (časy zeleně), ale status badge se nezobrazí (`flightStatus` z archivovaného flightboardu je `undefined`) — očekávané, ne bug.
