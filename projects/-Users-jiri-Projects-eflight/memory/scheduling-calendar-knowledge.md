---
name: scheduling-calendar-knowledge
description: "Architektura scheduling kalendáře (LegTimeline / vis-timeline) — lazy loading dat, mapování času na pixely, overlay gotcha"
metadata: 
  node_type: memory
  type: reference
  originSessionId: f0fe32ab-f4f1-473f-8634-0124457b7a06
---

Scheduling kalendář (Ganttova timeline na `/ops/`) — neobvyklé/nákladně zjistitelné věci.

Vše ve `src/Admin/Scheduling/screen/Calendar/`.

## Která komponenta je aktivní

- **`LegTimeline/`** je aktuálně vykreslovaný kalendář, postavený na knihovně **`vis-timeline/standalone`**.
  Tady žije veškerá živá logika (data, načítání, eventy, roster overlay, live FPL/CTOT).
- **`CalendarComponent/`** je starší vlastní implementace (custom DOM table/flex, `getNumOfPixelsForTimeDifference`).
  Není to plně mrtvý kód — LegTimeline z něj importuje pár utilit/subkomponent
  (`getStrippedBackgroundStyle`, `getMaintenanceData`). Před úpravou kalendáře vždy ověř, že
  míříš do `LegTimeline/`, ne do `CalendarComponent/`.

## Lazy loading dat podle viditelného okna (`useTimeline/`)

- `useTimelineUI.tsx` vytváří `VisTimeline`, registruje eventy. `rangechange` (scroll/zoom/`setWindow`)
  je jediné místo změny viditelného okna → volá `TIMELINE_DATA.setVisibleRange`.
- `useTimelineData.tsx`: `setVisibleRange` (throttle 100ms) → `isRangeLoaded` rozhodne barvu modrého
  kolečka (`LoadingSpinner.setBgColor`); `handleRangeChange` (debounce 500ms) → `addLoadRange`
  (optimisticky označí okno jako načtené) → `loadData(rangesToLoad)` fetchne přes `getCalendar`.
- `useLoadedRange.ts` drží načtené rozsahy v **refech** (nezpůsobují re-render), s utilitami
  `mergeRanges` / `getRangesToLoad`. **Dva nezávislé refy** (rozdělení přidáno v #2767):
  - `loadedRangesRef` — optimistický, plněný hned po odeslání požadavku (pro modré kolečko/spinner).
  - `loadedDataRangesRef` — až po reálném doručení dat z API (`markDataRangeLoaded` v `loadData`;
    pro proužek načtených úseků, viz [[2767-loaded-range-bar]]).
- Stav kalendáře NENÍ v reduxu/recoilu — data žijí v refech (`timelineDataRef`, `visibleRangeRef`).
  Propagace ven přes callback `onTimelineDataChange` → `timeline.setItems/setGroups`.

## `postprocessAndPropagateChange` = centrální hrdlo všech mutací dat osy

V `useTimelineData.tsx` prochází KAŽDÁ změna dat osy přes `postprocessAndPropagateChange(data)` —
loady (`loadData`), `changeReservation`, `addCreatedReservation`, `removeReservation`,
`changeFlightStatus(es)`, roster pozadí. Je to tedy správné (a jediné spolehlivé) místo pro globální
filtry/transformace dat, které musí platit bez ohledu na vstupní cestu. Sem patří: aplikace duty
chyb (`applyDutyErrorsToData` při `disableDutyPostprocessor`, jinak `DutyPostprocessor.process`) a
filtr quot s vytvořenou rezervací v sales view (`removeQuotesWithCreatedReservation`,
viz [[2769-hide-quote-with-reservation]]). Naopak `cleanCalendarLines` filtruje jen dávky z
`getCalendar` (NE živé cesty) — na globální invariant nespoléhat. Pozn.: empty-leg highlight
(#2402) jede zvlášť přes `useEffect` na změnu `emptyLegs` (přepočet stylu existujících itemů), ne
přes toto hrdlo.

## Mapování času na pixely

- `vis-timeline` nemá veřejné `timeToScreen`. Používá se `timeline.getWindow()` → `{ start, end }`
  + lineární interpolace přes naměřenou šířku panelu.
- DOM panely vis-timeline: `.vis-panel.vis-top` = horní časová osa (fixní při vertikálním scrollu,
  stejná horizontální geometrie jako obsah), `.vis-panel.vis-left` = levý panel se zdroji
  (šířka `HEADER_WIDTH` 300px, mobil 70px), `.vis-panel.vis-center` = obsah.

## GOTCHA: custom overlay nad vis-timeline

Vlastní overlay (proužek, marker…) přeměřuj geometrii **VŽDY na eventu `timeline.on('changed', …)`**
— ten fíruje až po dokončení redraw/layoutu. Synchronní měření hned po `new VisTimeline()` nebo
hned po `setItems/setGroups` vrátí ještě nehotový layout (levý panel ještě nemá šířku → `left = 0`),
takže overlay přeteče přes levý panel a opraví se až po prvním scrollu. Tohle byl bug fixnutý v #2767.

## Pattern imperativních overlay komponent

Loading indikátory/overlay používají `RefSpinner`-style pattern: `forwardRef` + `useImperativeHandle`
+ statická `useClass()` vracející `{ ref, … }`. Rodič volá metody imperativně (mimo render),
aby se vyhnul re-renderům celé timeline. Takto je dělaný `LoadingSpinner` i `LoadedRangeBar`.

Souvisí: [[2640-live-flight-updates]], [[2535-roster-calendar-display]], [[duty-calculation-knowledge]].
