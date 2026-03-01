# Fix: Chybějící local time odletu v scheduling calendar popupu (#2558)

## Problém

V Scheduling Calendar view se po najetí myší na let zobrazí popup s detaily.
U příletu se zobrazuje local time (např. `(18-Feb 0935LT)`), ale u odletu
se LT někdy nezobrazí – zobrazí se pouze Zulu čas (např. `0700Z`).

## Klíčové soubory

- **Popup komponenta:** `src/Admin/Scheduling/screen/Calendar/LegTimeline/LegPopupContent/index.tsx`
  - `Location` sub-komponenta (řádky 206-236) – zobrazuje airport, Zulu čas a podmíněně LT
  - LT se zobrazí jen když `isSome(localTimezone)` – jinak prázdné místo
- **Přiřazení timezone:** `src/Admin/Scheduling/screen/Calendar/ReservationForm/ChildEventForm/index.tsx`
  - `childEvent.calculations.locationFromTimezone` (departure)
  - `childEvent.calculations.locationToTimezone` (arrival)
  - Nastavuje se z `newAirport?.timezone` při výběru letiště
- **Popup trigger:** `src/Admin/Scheduling/screen/Calendar/LegTimeline/useTimeline/useTimelineUI.tsx`
  - Zobrazení na mouseMove event

## Příčina (k prozkoumání)

`locationFromTimezone` je pro odletové letiště `undefined`, proto se LT nezobrazí.
Potřeba zjistit, proč se timezone pro departure airport nenaplní – pravděpodobně
problém v datovém toku z backendu nebo při inicializaci dat pro timeline.
