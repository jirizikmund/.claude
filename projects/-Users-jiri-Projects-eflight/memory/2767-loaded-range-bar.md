---
name: 2767-loaded-range-bar
description: Task
metadata: 
  node_type: memory
  type: project
  originSessionId: f0fe32ab-f4f1-473f-8634-0124457b7a06
---

**Task #2767** — vizuální indikace, které časové úseky kalendáře (LegTimeline) jsou načtené.
Větev `feat/2767`, PR #2768 (na GitHub remote `origin` = veproza/eflight).

Tenký proužek pod hodinami v záhlaví: **modrá** = data úseku už dorazila z API, **šedá** = zatím
nenačteno. Vždy viditelný nezávisle na vertikálním scrollu (ukotvený na spodní hranu `.vis-panel.vis-top`),
při horizontálním scrollu/zoomu se přemapuje.

Klíčová rozhodnutí (uživatel):
- Modrá až po REÁLNÉM doručení dat (ne optimisticky jako modré kolečko) → druhý ref
  `loadedDataRangesRef` v `useLoadedRange.ts` (viz [[scheduling-calendar-knowledge]]).
- Finální vzhled (uživatel doladil ručně): výška `BAR_HEIGHT = 4`px, proužek posunutý nad šev
  (`top: geometry.top - BAR_HEIGHT`), barva načteno = `COLORS.blueInput`, nenačteno = `COLORS.gray200`.

Dotčené soubory: nová `LegTimeline/LoadedRangeBar.tsx` (imperativní komponenta, mapuje rozsahy na px
přes `timeline.getWindow()` + geometrii `.vis-panel.vis-top`); `useLoadedRange.ts`,
`useTimeline/useTimelineData.tsx`, `useTimeline/useTimelineUI.tsx`, `LegTimeline/index.tsx`.

Původně 2 commity (feature + fix přetékání proužku přes seznam letadel při prvním načtení; přepočet
navázán na vis-timeline event `changed` — viz overlay gotcha v [[scheduling-calendar-knowledge]]).

**Stav (15.6.2026):** lokálně squashnuto do jednoho commitu `63383c802`
`(#2767) Show loaded date ranges as a bar in the calendar header` (přes `reset --soft origin/master`,
obsah ověřen identický s předsquashovým HEAD). Lokální `feat/2767` se rozchází s `origin/feat/2767`
→ čeká na **force-push od uživatele** (`! git push -f origin feat/2767`), pak se PR #2768 aktualizuje.
