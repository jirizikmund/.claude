# #2402 — Duty chyby posádky na rezervační časové ose (quote)

## Context

GitHub issue #2402: na časové ose v detailu **quotation** zobrazovat chyby normy (duty) posádky
jako v kalendáři. **Cíl (upřesněno klientem):** plánovač má vidět, **jaká bude duty, když rezervaci
prodá** — tj. norma pro stav *po prodeji* quote.

**Stav:** první kolo implementováno (commit `ff6ea31c4`, větev `feat/2402`): nový hook
`useReservationDutyErrors`, opt-out `DutyPostprocessor` na quote ose, injekce `dutyErrors` přes
`applyDutyErrors`, fix `userId` v `DutyDataLoader`. Render proužku + popup badge sdílený s kalendářem
funguje. **Toto kolo = oprava SADY legů, na které se norma počítá**, aby odpovídala realitě po prodeji.

### Co ukázalo ověření (display + datové zdroje)

- **Quote osa = jen řádek letadla** (`linesResourceIds:[aircraftId]`). `loadData`→`getCalendar(isQuotation:false)`
  navíc načítá **okolní potvrzené rezervace téhož letadla**; legy quote přidává `changeReservation`
  (šrafované). Empty legy (`‹s›E‹/s›`) i cancelled (`cancelled`, přeškrtnuto) se **zobrazují** —
  zobrazení necháváme být, mění se jen výpočet.
- **`EmptyLegToRemove` NEJSOU legy quote** — jsou to empty legy *jiných* rezervací na stejném
  letadle, které by prodej quote zrušil (na ose červeně). Můj dosavadní filtr běžel nad
  `reservation.events` → **no-op**.
- **Kalendář bere nadcházející rozvrh posádky z on-screen řádků pilotů** (getCalendar načte všechny
  řádky; `DutyPostprocessor.matchItemsToPilotData` je seskupí). DB `loadDutyDataForContactIds`
  (`legsAsPic` limit 8 od včera + logbook týden + duties kvartál) je jen **kumulativní historie**,
  NE nadcházející rozvrh. Quote osa je aircraft-filtrovaná → **rozvrh pilota na jiných letadlech chybí**.

### Rozhodnutí (potvrzeno uživatelem)

1. **Cancelled legy** quote: na ose zobrazit, ale **do normy NEpočítat** (po prodeji se nepoletí).
2. **Odebírané empty legy** (`EmptyLegToRemove`): **z normy vyloučit** (po prodeji zaniknou) — opravit
   filtr na správnou sadu.
3. **Zdroj rozvrhu posádky = varianta A: donačíst rozvrh posádky jako kalendář** (per-pilot napříč
   letadly). Norma je per-pilot přes všechna letadla; jen-toto-letadlo nebo jen-DB-historie by dávaly
   falešný výsledek.

## Approach

Rozšířit `useReservationDutyErrors` tak, aby pro každého pilota quote počítal normu ze **stejných
zdrojů jako kalendář** + quote-scénářové úpravy. Mechanika kopíruje `DutyPostprocessor` (max reuse,
žádná nová „duty logika").

Vstupní sada leg-likes per pilot (po prodeji):
```
quoteLegLikes            (reservation.events pilota: !deleted, !cancelled, !emptyLegToRemove)
+ crewScheduleLegLikes   (rozvrh pilota z getCalendar: !deleted, !cancelled, !emptyLegToRemove,
                          BEZ self quote)
+ remote.legs/logbook    (DB historie pro kumulativní okna — beze změny)
+ remote.duties          (existující duty items — beze změny)
```

## Implementace

### 1. `useReservationDutyErrors.ts` — donačtení rozvrhu posádky (varianta A)
`src/Admin/Scheduling/screen/Calendar/ReservationForm/AircraftTimeline/useReservationDutyErrors.ts`

- **Nový async load rozvrhu pilotů** (vedle `useRemoteDutyData`): `getCalendar` (`src/Admin/Scheduling/Datasources/getCalendar`)
  s `filter: { linesResourceIds: [<contactIds pilotů>] }`, `isQuotation:false`, okno = rozsah quote
  ± buffer (pár dní, kvůli FDP/rest sousedních dnů). Výsledné `CalendarLine[]` → pro každý pilotní
  line projít `line.reservations` → jejich `events` (childEventy) → `childEventToFlightLegLike`.
  - `useEffect` s `canceled` guardem; cache klíč = serializace contactIds + okno (jako u `useRemoteDutyData`).
- **Filtr rozvrhu posádky** (= post-sale úprava), aplikovaný na childEventy z getCalendaru:
  - `!childEvent.deleted`
  - `!ChildEventUtils.isCancelled({childEvent, reservation})` (Q1)
  - **vyloučit `EmptyLegToRemove`** (Q2) — match `el.reservationId === reservation.id && el.childEventId === childEvent.id`
    (tady už dává smysl: tyto legy jsou v rozvrhu *jiných* rezervací).
  - **vyloučit self** — childEventy patřící do právě editované quote (`reservation.id` quote), aby se
    nezdvojily s `quoteLegLikes`.
  - jen legy, které pilot reálně letí (`isChildEventVisibleForResource`).
- **`quoteLegLikes`** beze změny: z `reservation.events` (quote) — `!deleted`, `!cancelled`,
  `!isEmptyLegToRemove`, `isChildEventVisibleForResource`. Pozn.: u quote je `isEmptyLegToRemove`
  fakticky no-op (legy quote nejsou EmptyLegToRemove), ale ponechat pro robustnost.
- **Výpočet** (per pilot, jako dnes): `allLegLikes = [...remote.legs, ...remote.logbookRecords,
  ...crewScheduleLegLikes, ...quoteLegLikes]`; `autocreateDuties([...quoteLegLikes, ...crewScheduleLegLikes], contact)`;
  `computeDuties([...remote.duties, ...previewDutyItems], baseAirportIcaos, legMap, new Map())`;
  `getDutyErrorsMapByLegId(dutyLines, eventIdWhitelist)`.
  - **`eventIdWhitelist`** = jen `quoteLegLikes` ids → proužek/badge se ukáže jen na legách quote
    (okolní rozvrh slouží jen jako kontext pro výpočet, nezobrazuje chyby na cizích legách).
  - dedup leg-likes podle `id` přes `toMap` (childEvent.id rozvrhu vs quote — různé id, ok; self-exclusion
    řeší případný překryv).

### 2. (beze změny) opt-out + injekce
`useTimelineData.tsx` (`disableDutyPostprocessor`, `applyDutyErrors`) a `AircraftTimeline/index.tsx`
zůstávají — jen se mění obsah mapy z hooku. Zobrazení empty/cancelled legů na ose se nemění.

### 3. Reuse (neimplementovat znovu)
`getCalendar`, `childEventToFlightLegLike`, `isChildEventVisibleForResource`, `computeDuties`,
`autocreateDuties`, `getDutyErrorsMapByLegId(…, whitelist)`, `loadDutyDataForContactIds`,
`mergeScheduleErrorMaps`, `ChildEventUtils.isCancelled`. Vzor kombinace: `DutyPostprocessor.recomputeDutyErrors`
+ `useScheduleDutyIssues`.

## Verifikace (ručně v appce — vizuál kontroluje uživatel)
1. Quote, kde pilot má **na jiném letadle** týž den nahuštěný let → norma quote ho zohlední (proužek/badge
   se objeví, i když na tomto letadle je quote „v pohodě").
2. Quote přes existující **empty leg jiné rezervace** (EmptyLegToRemove, červeně na ose) → tento empty leg
   se do normy **nepočítá** (po prodeji zanikne).
3. **Cancelled** leg quote → na ose vidět, do normy se nepočítá.
4. Regrese kalendáře (pilotní řádky) — duty beze změny (`disableDutyPostprocessor` jen na quote ose).
5. `npx tsc --noEmit` + `eslint` čisté.

## Fragilní místa
- Okno `getCalendar` pro rozvrh: dost velké pro FDP/rest sousedních dnů, ne zbytečně široké (perf).
  Kumulativní limity (28/90 d/rok) řeší remote `duties` — okno rozvrhu je nemusí pokrýt.
- Dva async zdroje (rozvrh + remote) → `canceled` guardy, stabilní cache klíče, `useDeepEqualMemo` na
  vstupech, aby `applyDutyErrors` necpalo `setData` zbytečně.
- Self-exclusion editované quote z načteného rozvrhu (quote je `isQuotation` → getCalendar(isQuotation:false)
  by ji neměl vrátit, ale ošetřit i podle `reservation.id`).
- `eventIdWhitelist` musí zůstat jen na legách quote, jinak by se chyby ukazovaly i na cizích barech.
