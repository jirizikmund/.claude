# Plán: flightData jako nejvyšší prioritní zdroj reálných časů odletu/příletu v scheduling kalendáři

## Context

V úkolu #2640 jsme do scheduling kalendáře přidali živá data letů (FPL, CTOT, actual
departure/arrival) s prioritou `actualDeparture > CTOT > FPL > scheduled`. Reálné časy
(actual departure/arrival, zdroj eTLB/TLB) jsou ale dnes dostupné jen z flightboardu, a ten
drží data jen v okně cca **[now − 2h, now + 24h]**. Starší lety tak ve schedulingu padají zpět
na scheduled časy — historicky nevidíme reálné časy vzletu/přistání.

Kolega Lukáš Vlček na větvi `feature/flightdata` (commit `985911cee`) přidal na objekt
rezervace nový field `flightData`, který nese reálné časy (eTLB) **kdykoliv zpětně** — tedy i
pro lety mimo 2h okno flightboardu. Cíl: použít `flightData` (pokud existuje) jako **úplně
nejvyšší prioritní** zdroj actual departure/arrival, takže v kalendáři v minulosti vždy uvidíme
reálné časy. Veškerá ostatní logika (#2640) zůstává beze změny — `flightData` jen přibyde jako
nový nejvyšší zdroj actuals.

## Datový model (ověřeno)

`@eflight/shared/src/scheduling/types/index.ts:316`
```ts
export type FlightData = { flights: FlightDataItem[] };
export type FlightDataItem = { departure: Date; arrival: Date; childEventId: string };
```
- `Reservation.flightData?: FlightData` (`src/Admin/Scheduling/model/SchedulingTypes.ts:387`).
- Mapování na leg přes `childEventId === childEvent.id`.
- **Pozor:** `flightData` se parsuje přes `safeJsonParse` **bez** `dateTimeReviver`
  (`SchedulingTypes.ts:459-462`), takže `departure`/`arrival` jsou za běhu **ISO stringy**, ne
  `Date`. To řeší existující helper `toDate()` v `effectiveTimes.ts:25`, který přijímá `Date | string`.

## Přístup

Reálné časy z `flightData` mají stejnou sémantiku jako stávající `actualDeparture`/`actualArrival`
ve `FlightInfo` — jen z trvalého zdroje. Vložíme je proto jako nejvyšší prioritu přímo do
centrální funkce `deriveEffectiveTimes`. Tím se nový zdroj automaticky propíše do **všech**
konzumentů (pozice baru, časy v baru, popup Departed/Landed, výpočet duty normy) jednotnou
prioritou, bez duplikace logiky.

Protože všech 6 call sites má v dosahu jak `reservation`, tak `childEvent`, přidáme malý helper a
na každém místě ho předáme jako nový (volitelný) argument.

### 1. Helper `ChildEventUtils.getFlightData` — `src/Admin/Scheduling/utils/childEvent.ts`

Paralela ke stávající `isCancelled({ childEvent, reservation })`. `Reservation` i `ChildEvent`
už jsou v souboru importované, `FlightDataItem` se odvodí inferencí (žádný nový import):
```ts
function getFlightData(params: { childEvent: ChildEvent; reservation: Reservation }) {
    return params.reservation.flightData?.flights.find((f) => f.childEventId === params.childEvent.id);
}
```
Přidat `getFlightData` do exportovaného objektu `ChildEventUtils` (kolem `childEvent.ts:167-188`).

### 2. `deriveEffectiveTimes` — `src/Admin/Flightboard/models/effectiveTimes.ts`

Přidat nový volitelný 5. parametr **před** `now` (žádný caller `now` nepředává, takže je to
bezpečné a 4-argumentová volání zůstanou platná). Strukturální typ, aby se model
nemusel vázat na shared `FlightDataItem`:
```ts
export function deriveEffectiveTimes(
    scheduledFrom: Date,
    scheduledTo: Date,
    flightInfo: FlightInfo | undefined,
    isCancelled: boolean,
    flightDataTimes?: { departure?: Date | string | null; arrival?: Date | string | null },
    now: Date = new Date()
): EffectiveTimes
```
Změnit jen extrakci actuals (řádky 64-65) — `flightData` má přednost před `flightInfo`:
```ts
const actualDeparture =
    toDate(flightDataTimes?.departure) ?? toDate(flightInfo?.actualDeparture?.date as Date | string | undefined);
const actualArrival =
    toDate(flightDataTimes?.arrival) ?? toDate(flightInfo?.actualArrival?.date as Date | string | undefined);
```
Vše ostatní (`phase`, `effectiveTimeOut/In`, 24h gate, `isShifted`, `getLegTimeSlots`) zůstává
beze změny. Výsledná priorita actuals: **flightData > flightboard actual > CTOT > FPL > scheduled**.

Důsledky (žádanou cestou, bez další úpravy logiky):
- Historický leg s `flightData` → `actualDeparture` i `actualArrival` vyplněny → `phase='landed'`
  → bar od reálného odletu po reálný přílet, časy zeleně, `isShifted=false` (šrafa po přistání
  bezpodmínečně mizí — viz #2640).
- Popup ukáže vlevo „Departed", vpravo „Landed" (zeleně) i pro staré lety.

### 3. Předat helper do všech volání `deriveEffectiveTimes`

Všech 6 míst už `ChildEventUtils` importuje. Přidat 5. argument:

| Soubor | Řádek | Argument |
|---|---|---|
| `useTimelineData.tsx` (`changeFlightStatus`) | ~141 | `ChildEventUtils.getFlightData({ childEvent: item.data.childEvent, reservation: item.data.reservation })` |
| `useTimelineData.tsx` (`changeFlightStatuses`) | ~196 | `ChildEventUtils.getFlightData({ childEvent: data.childEvent, reservation: data.reservation })` |
| `useTimelineData.tsx` (`getDataItemsFromReservationForOneResource`) | ~656 | `ChildEventUtils.getFlightData({ childEvent, reservation })` |
| `LegPopupContent/index.tsx` | ~51 | `ChildEventUtils.getFlightData({ childEvent, reservation })` |
| `calendarDuties.ts` (`childEventToFlightLegLike`) | ~33 | `ChildEventUtils.getFlightData({ childEvent, reservation })` |
| `DutyPostprocessor.ts` (`updateDataWithErrors`) | ~155 | `ChildEventUtils.getFlightData({ childEvent: item.data.childEvent, reservation: item.data.reservation })` |

Poznámka: úprava v `childEventToFlightLegLike` (calendarDuties.ts) pokrývá oba jeho callery
(`getReservationDuty` i `DutyPostprocessor.transformItemsToLegLikes`) najednou — funkce už
`reservation` dostává. Tím se reálné historické časy propíší i do výpočtu duty normy, což je
konzistentní (duty calc už dnes actuals z effective times používá).

## Vědomé předpoklady

- **flightData = absolutní nejvyšší priorita** (dle zadání „úplně nejprioritnější zdroj").
  Pro live lety v 2h okně `flightData` typicky ještě nemá záznam (backend ho zapisuje při
  archivaci po přistání) → spadne na `flightInfo` actuals, takže žádná regrese live chování.
  Když oba zdroje existují, nesou stejná data (flightData je odvozen z týchž flightboard actuals).
- **Status badge** se u historických legů nezobrazí (`flightStatus` z archivovaného flightboardu
  je `undefined`) — bar ukáže reálné časy zeleně, ale bez živého badge. To je očekávané; zadání se
  týká časů, ne badge.

## Ověření

1. **Typová kontrola + lint:** `npm run build` (resp. `tsc`) a prettier (respektovat konfiguraci).
2. **Manuální vizuální kontrola** (uživatel kontroluje ručně — inspector nespouštět automaticky):
   - Otevřít scheduling kalendář, odscrollovat do minulosti (lety starší než 2h, ideálně dny zpět)
     u rezervace, která má `flightData`. Bar musí stát na reálném odletu→přílet, časy zeleně,
     popup „Departed"/„Landed".
   - Porovnat s rezervací bez `flightData` v minulosti — musí zůstat beze změny (scheduled).
   - Ověřit, že aktuální/budoucí lety v 2h+24h okně se chovají jako dosud (#2640 nezměněno).
3. Po dokončení aktualizovat memory `2640-live-flight-updates.md` — dosud otevřený bod „TLB
   fallback po 2h" je tímto vyřešen přes `flightData`.
