---
name: duty-chyby-pos-dky-na-rezerva-n-timeline-2402
description: "Zobrazení chyb normy (FDP/Rest/...) posádky na Aircraft Timeline v quotation rezervaci — architektura, rozhodnutí, stav."
metadata: 
  node_type: memory
  type: project
  originSessionId: b76d7531-212b-4c14-b294-28143b30f927
---

# #2402 — Duty chyby posádky na rezervační časové ose

**Stav: HOTOVO, vizuálně ověřeno. Squash commit `e6638e81a` na `feat/2402`** (6 souborů, +397/−22;
1.+2. kolo + robustness fixy sloučeno/amendnuto 9.6.2026 — pozn. hash se rebasem/amendem mění).
**Nepushnuto** — sync na origin/feat/2402 bude potřebovat force-push (na uživateli). Klient
(Alpha Aviation / Marcel) zadání potvrdil.

**CR (blast-radius) + vizuální test 9.6.2026:** push je bezpečný — změna je aditivní, nová logika
v `useTimelineData` je za opt-in flagem `disableDutyPostprocessor` (jen quote osa), kalendář má
else-větev byte-identickou; `mergeScheduleErrorMaps` ≡ původní `mergeMaps`; `userId` se v
`computeDuties` nepoužívá → kalendář bez regrese (ověřeno 2 adversariálními agenty). Robustness:
doplněn `.catch()` v `useRemoteDutyData` + guard na nevalidní datum v `getScheduleWindow`.
Visual inspector potvrdil: Aircraft Timeline se vykresluje, červené duty proužky na barech, popup
s badgi (FDP/7 days/Day Off Week), žádné console chyby z nové logiky. Screenshoty v
`memory/screenshots/2402-*.png` (25 ks; pozn. inspector je uložil do rootu repa, ručně přesunuto).

**Why:** Hlavní kalendář duty chyby umí (proužek na baru + FDP/Rest badge v popupu), ale
rezervační `AircraftTimeline` (jen quotation mód) je filtrovaná na `linesResourceIds:[aircraftId]`
→ žádné pilotní řádky → sdílený `DutyPostprocessor` se spoléhal na fragilní async cestu a duty
fakticky nespolehlivě nepočítal.

## Řešení (varianta B — dedikovaný hook + opt-out postprocessoru)

- **Nový hook** `src/Admin/Scheduling/screen/Calendar/ReservationForm/AircraftTimeline/useReservationDutyErrors.ts`
  (vzor `src/screens/Welcome/Schedule/useScheduleDutyIssues.ts`): per pilot (PIC+FO z
  `reservation.resources` nebo per-leg při `diffCrewForEachEvent`) spočítá `ScheduleErrorMap`.
  Kombinuje `loadDutyDataForContactIds` (scheduling legy posádky z DB) + quote legy.
  **Filtr (jádro zadání):** vynechá `deleted`, `ChildEventUtils.isCancelled`, a odebírané empty
  legy (`emptyLegs: EmptyLegToRemove[]` match `childEventId+reservationId`). `eventIdWhitelist`
  omezí chyby jen na legy rezervace. Merge přes piloty `mergeScheduleErrorMaps`.
- **`useTimelineData.tsx`**: nový param `disableDutyPostprocessor?` (přeskočí `DutyPostprocessor`,
  místo toho aplikuje `dutyErrorMapRef` přes `applyDutyErrorsToData` při každém rebuildu dat) +
  imperativní `applyDutyErrors(map)` + `serializeDutyErrors` + `EMPTY_DUTY_ERROR_MAP`. Vyexportováno
  `isChildEventVisibleForResource`. Default chování (kalendář) beze změny.
- **`AircraftTimeline/index.tsx`**: `disableDutyPostprocessor:true`, volá hook, effect
  `applyDutyErrors(dutyErrorMap)`. Odstraněn zapomenutý `console.log({newData})`.
- **`dutyErrorExtractor.ts`**: vytažena sdílená `mergeScheduleErrorMaps` (používá hook i
  refaktorovaný `DutyPostprocessor.recomputeDutyErrors`).
- **`DutyDataLoader.ts`** (bonus fix): `processDutyQuery` doplnil chybějící `userId` do výstupního
  `contact` (předtím `autocreateDuties` dostával `userId='X'`).

## Potvrzená rozhodnutí
- Rozsah: **jen quotation** (kde se AircraftTimeline renderuje).
- Vizuál: **jako v kalendáři** (proužek + popup badge), žádný nový bar badge.
- Výpočet: scheduled legy posádky z DB (omezené okno `DutyDataLoader.getTimeFilters`) + quote legy.

## 2. kolo (8.6.2026) — sada legů pro „post-sale" duty (varianta A) — squashnuto do `4e52218cd`

**Cíl upřesněn klientem:** „jaká bude duty, když rezervaci prodám" = norma pro stav PO prodeji.

**Ověřené rozdíly quote osa vs kalendář:**
- Quote osa = jen řádek letadla (`linesResourceIds:[aircraftId]`); `getCalendar(isQuotation:false)` načítá i okolní potvrzené rezervace téhož letadla, legy quote přidává `changeReservation` (šrafované). Empty (`‹s›E‹/s›`) i cancelled (`cancelled`) se zobrazují — display neměníme.
- **`EmptyLegToRemove` = empty legy JINÝCH rezervací na témž letadle, které prodej zruší** (ne legy quote). Můj filtr 1. kola nad `reservation.events` byl no-op.
- **Kalendář bere nadcházející rozvrh posádky z on-screen řádků pilotů** (getCalendar bez aircraft filtru); DB `loadDutyDataForContactIds` je jen kumulativní historie (legsAsPic limit 8 od včera, logbook týden, duties kvartál), NE nadcházející rozvrh.

**Rozhodnutí uživatele:** (1) cancelled na ose zobrazit, do normy NEpočítat; (2) odebírané empty legy z normy vyloučit; (3) **varianta A** — donačíst rozvrh posádky napříč letadly jako kalendář (norma je per-pilot přes všechna letadla).

**Změna (jen `useReservationDutyErrors.ts`):** nový `useCrewScheduleLegLikes` → `getCalendar({filter:{linesResourceIds:[pilotIds]}, isQuotation:false, loadContacts:false, loadAircrafts:false})` pro okno = rozsah quote ±3 dny (zaokrouhleno na dny). Z pilotních linek `line.reservations.events` → `reservationLegLikesForPilot` (sdílený filtr: `!deleted`, `!isCancelled`, `!isEmptyLegToRemove`, `isChildEventVisibleForResource`), bez self quote. `computeReservationDutyErrors`: `scheduleLegLikes = quote legy + crew rozvrh`; `autocreateDuties(scheduleLegLikes)`; `computeDuties([...remote.duties, ...preview], …, legMap)`; whitelist = jen legy quote. Zachován opt-out postprocessoru + `applyDutyErrors` z 1. kola (beze změny). tsc + eslint čisté.

## Pozn.
- "QP" badge v zadání = reservation flag (`allFlagsData` v `LegPopupContent`), NE duty — mimo scope.
- Duty render mechanismus + výpočet (computeDuties/autocreateDuties/getDutyErrorsMapByLegId/
  childEventToFlightLegLike) viz [[2640-live-flight-updates]].
- tsc čistý, eslint 0 errors (jen pre-existing style warnings).
