---
name: duty-calculation-knowledge
description: "Jak scheduling počítá normu (duty/FDP) posádky — datové zdroje, klíčové funkce, EmptyLegToRemove, getCalendar. Pro budoucí práci na duty/normě."
metadata: 
  node_type: memory
  type: project
  originSessionId: b76d7531-212b-4c14-b294-28143b30f927
---

# Výpočet normy (duty/FDP) posádky ve schedulingu

Non-obvious data-flow zjištěný hloubkovým zkoumáním (#2402) — není čitelný z jednoho souboru.

## Klíčové funkce
- `src/utils/Duties/DutyCalculator.ts` — `computeDuties(dutyItems, homebases, legMap, aircraftMap)` → `TableDutyLine[]`. Jádro: FDP, rest, kumulativní limity (block/duty 7/28/90 d + 12 m), days-off. **`userId` NEpoužívá** (je jen metadata na `DutyItem`; potvrzeno grepem).
- `src/utils/Duties/DutyAutoCreator.ts` — `autocreateDuties(legLikes, {userId, crewId, baseAirportIcaos})` → seskupí legy do duty period podle rest gapů; `userId/crewId` jen metadata. Běží **per pilot zvlášť**.
- `src/Admin/Scheduling/model/Duty/dutyErrorExtractor.ts` — `getDutyErrorsMapByLegId(lines, eventIdWhitelist?)` → `Map<legId,{errors,warnings}>` (chyba se přiřadí **VŠEM** legům duty linky, ne jen jednomu); `dutyIssueToErrorTitle` → badge text (FDP/Rest/7 days/28 days/12 months/…block/Days Off…); `mergeScheduleErrorMaps`.
- `childEventToFlightLegLike(childEvent, reservation, flightInfo?)` (`ReservationForm/ReservationDuties/calendarDuties.ts`) — scheduling childEvent → leg-like (časy přes `deriveEffectiveTimes`).

## Dva datové zdroje (KLÍČOVÉ)
Kalendář (`DutyPostprocessor`) i hook #2402 kombinují:
1. **Nadcházející rozvrh = scheduling childEventy.** Kalendář je bere z **on-screen řádků pilotů** (`getCalendar` načte všechny řádky; `matchItemsToPilotData` seskupí položky `resource.type===pilot`). Toto je primární zdroj upcoming letů → jdou do `autocreateDuties`.
2. **Kumulativní historie z DB = `loadDutyDataForContactIds(contactIds)`** (`model/Duty/DutyDataLoader.ts`): per pilot `legsAsPic/legsAsSic` (Leg model, limit 8, `timeOut≥včera`, `!deleted`), `logbookRecords` (týden), `duties` (kvartál). **NEjsou to scheduling rezervace** — jen operační Leg/logbook/duty záznamy pro klouzavá okna. **Na upcoming rozvrh se NESPOLÉHAT.**

→ `computeDuties([...remote.duties, ...autocreateDuties(scheduleLegLikes)], homebases, legMap)`; `legMap = toMap([...remote.legs, ...remote.logbook, ...scheduleLegLikes])`.

`DutyPostprocessor` má async race (`lastProcessData !== data` zahodí refresh) — proto #2402 na quote ose postprocessor vypíná (`disableDutyPostprocessor`) a počítá vlastním hookem.

## EmptyLegToRemove (scénář prodeje quote)
`EmptyLegToRemove` = empty legy **JINÝCH** rezervací na stejném letadle, které prodej quote zruší (**NE** legy quote). Zdroj: backend `/reservation/emptyLegsToRemove` (overlap s legy quote, ±2 dny). Při prodeji: `createReservationFromQuotationId(quoteId, {legsToCancelledId})` + `addCancelledLegs([{reservationId, eventId, replacedByReservationId}])`. Filtr `el.reservationId===reservation.id && el.childEventId===childEvent.id` má smysl jen nad legy oněch **jiných** rezervací (ne nad legy quote).

`ChildEventUtils.isCancelled({childEvent,reservation})` = `slsCancelled || opsCancelled || reservation.cancelledLegs.find(eventId===childEvent.id)`. Cancelled leg přes `deriveEffectiveTimes` stále vrací leg-like se scheduled časy (phase 'cancelled') — do duty se počítá, pokud ho explicitně nevyfiltruješ.

**Tři stavy legu vs zobrazení na timeline (ověřeno 12.6.2026):** `deleted: true` se NEZOBRAZUJE NIKDY — odfiltrován už při loadu z DB (`reservationDataToReservation` → `convertChildEvents` → `filter(isNotDeleted)`, totéž resources), proto timeline/duty kód žádný deleted filtr nemá a spoléhá na čistá data. Cancelled SE zobrazuje (červený, přeškrtnuté ICAO, „CANCELLED" v popupu), do normy se nepočítá. `EmptyLegToRemove` = normální (zatím nezrušený) leg cizí rezervace — zobrazuje se, červené zvýraznění od fixu `3ae543566`. Backend `/reservation/emptyLegsToRemove` deleted legy nenabízí (`isNotDeleted` + jen budoucí legy).

## getCalendar (`Datasources/getCalendar.ts`)
`getCalendar({dateFrom,dateTo,filter,isQuotation,loadContacts,loadAircrafts})` → `{result: CalendarLine[], maintenancePromise}`. `CalendarLine = {resource, reservations: Reservation[]}`. `filter.linesResourceIds` → `showResourceLine` gate (jen vyjmenované linky). Reservace se přiřadí na linku podle **všech** resources (reservation-level + childEvent non-aircraft). `loadContacts/loadAircrafts` gateují **jen** `maintenancePromise` (linky vznikají i on-demand z rezervací). `isQuotation:false` = potvrzené rezervace, ne quoty. → lze donačíst rozvrh konkrétních pilotů: `filter:{linesResourceIds:[pilotIds]}, isQuotation:false`.

## Zobrazení chyb (sdílené napříč kalendářem i quote osou)
`getItemContentPropsBasedOnData` → className `duty-error`/`duty-warning` = levý border proužek (`LegTimeline/styles.sass`). `LegPopupContent` → badge z `dutyIssueToErrorTitle`. Timeline item nese `data.dutyErrors: ScheduleDutyIssues|null`.

Souvisí: [[2402-duty-reservation-timeline]], [[2640-live-flight-updates]], [[reservation-form-knowledge]].
