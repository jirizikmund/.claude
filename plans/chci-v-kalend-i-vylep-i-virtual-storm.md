# Proužek načtených úseků v záhlaví kalendáře (vis-timeline)

## Context

V scheduling kalendáři (`LegTimeline`, postavený na `vis-timeline`) se data načítají lazy podle
viditelného časového okna. Stávající logika (`useLoadedRange.ts`) detekuje, které časové rozsahy
jsou pokryté, a indikuje nenačtený stav malým modrým kolečkem (`RefSpinner`) + animovaným spinnerem
během fetchování.

Cílem je přidat **horizontální proužek pod hodinami v záhlaví kalendáře**, který je vždy viditelný
nezávisle na vertikálním scrollu a barevně odlišuje pokrytí časové osy:

- **modrá** (`blueInput` `#147EFB`) = úsek, jehož data už reálně dorazila z API,
- **šedá** (`gray200` `#C8C8C8`) = úsek zatím nenačtený.

Rozhodnutí potvrzená uživatelem:
- Úsek zmodrá **až po skutečném doručení dat z API** (ne optimisticky jako modré kolečko) →
  je potřeba sledovat reálně načtené rozsahy zvlášť.
- Proužek je **výraznější, ~8 px vysoký**.

## Klíčové soubory a architektura (zjištěno průzkumem)

Vše ve `src/Admin/Scheduling/screen/Calendar/LegTimeline/`:

- `useTimeline/useLoadedRange.ts` — drží `loadedRangesRef` (optimisticky, pro kolečko). Obsahuje
  čistou utilitu `mergeRanges()` a `getRangesToLoad()`. `DateRange = { start: Date; end: Date }`.
- `useTimeline/useTimelineData.tsx` — `loadData()` (řádky ~353–431) iteruje `loadRanges` a po každém
  `getCalendar()` mergeuje data; `handleRangeChange` (optimistické `addLoadRange`) a `setVisibleRange`
  (kolečko přes `LoadingSpinner.setBgColor`). Filter-change effect (~464) volá `clearLoadedRanges()`.
- `useTimeline/useTimelineUI.tsx` — vytváří `VisTimeline`, registruje `rangechange` (řádky ~170–195)
  = jediné místo, kde se mění viditelné okno (scroll/zoom/`setWindow`). Drží `containerRef`.
- `index.tsx` — renderuje wrapper `View.vis-timeline-wrapper` s `<div ref={containerRef} />`;
  drží `timelineRef` a `TIMELINE_DATA`.
- `RefSpinner` (`src/components/common/RefSpinner/index.tsx`) — vzor imperativní komponenty s
  `useImperativeHandle` + `useClass()`, který následujeme.
- Barvy: `src/stylekit` → `COLORS` (`blueInput`, `gray200`).

**Mapování času → pixely:** `vis-timeline` nemá veřejné `timeToScreen`, ale má `timeline.getWindow()`
→ `{ start, end }`. Panel `.vis-panel.vis-top` (časová osa) má stejnou horizontální geometrii jako
obsah a **zůstává fixní při vertikálním scrollu**. Segment se spočítá lineární interpolací uvnitř
naměřené šířky panelu — žádné globální offsety nejsou potřeba.

## Návrh řešení

### 1. `useLoadedRange.ts` — sledovat reálně načtené rozsahy

Přidat druhý, nezávislý ref pro **skutečně načtená data** (stávající `loadedRangesRef` pro kolečko
nechat beze změny):

```ts
const loadedDataRangesRef = useRef<DateRange[]>([]);

const markDataRangeLoaded = useCallback((range: DateRange) => {
    loadedDataRangesRef.current = mergeRanges([...loadedDataRangesRef.current, range]);
}, []);

const getLoadedDataRanges = useCallback(() => loadedDataRangesRef.current, []);
```

V `clearLoadedRanges` vynulovat i `loadedDataRangesRef.current = []`.
Doplnit `markDataRangeLoaded` a `getLoadedDataRanges` do návratového objektu. `mergeRanges` se
reusne (už existuje v modulu).

### 2. Nová komponenta `LoadedRangeBar.tsx` (ve složce `LegTimeline/`)

Imperativní komponenta podle vzoru `RefSpinner` — `forwardRef` + `useImperativeHandle({ update })`
+ `useClass()` vracející `{ ref, update }`.

Props: `timelineRef`, `containerRef`, `getLoadedRanges: () => DateRange[]`.

`update()`:
- `const timeline = timelineRef.current; if (!timeline) return;`
- `const win = timeline.getWindow();` (`{ start, end }`)
- Naměřit geometrii z DOM:
  `const topPanel = containerRef.current?.querySelector('.vis-panel.vis-top')`,
  `const containerRect = containerRef.current.getBoundingClientRect()`,
  `const topRect = topPanel.getBoundingClientRect()`.
  → `left = topRect.left - containerRect.left`, `width = topRect.width`,
  `top = topRect.bottom - containerRect.top` (proužek sedí přímo pod osou).
- Spočítat segmenty: pro každý `range` z `getLoadedRanges()` ho protnout s `[win.start, win.end]`
  a namapovat na px:
  `x = (t - win.start) / (win.end - win.start) * width`, ořezat do `[0, width]`.
- Uložit do stavu `{ left, top, width, segments }` → re-render.

Render (absolute uvnitř wrapperu):
- vnější div: `position:absolute`, `left`, `top`, `width`, `height: 8`,
  `background: COLORS.gray200`, `zIndex` nad obsahem osy, `pointerEvents:'none'`.
- pro každý segment vnitřní div: `position:absolute`, `left`/`width` v px, `height:'100%'`,
  `background: COLORS.blueInput`.

Komponenta si interně přidá `window` resize listener (přes `requestAnimationFrame`/throttle), který
zavolá `update()` kvůli přepočtu šířky.

### 3. `useTimelineData.tsx` — napojení

- `const loadedRangeBarRef = useRef<{ update: () => void }>(null);`
- `const updateLoadedRangeBar = useCallback(() => loadedRangeBarRef.current?.update(), []);`
- V `loadData()` na konci každé iterace `loadRange` (po zmergování dat z `getCalendar`) zavolat
  `LoadedRange.markDataRangeLoaded(loadRange); updateLoadedRangeBar();` — tím úsek zmodrá až po
  doručení dat. Pro maintenance větev to umístit tak, aby se značilo po zpracování legů.
- Ve filter-change effectu po `clearLoadedRanges()` zavolat `updateLoadedRangeBar()` (vyresetuje na šedou).
- Do návratového objektu doplnit: `loadedRangeBarRef`, `updateLoadedRangeBar`,
  `getLoadedDataRanges: LoadedRange.getLoadedDataRanges`.

### 4. `useTimelineUI.tsx` — repozice při změně okna

- V handleru `rangechange` (po `TIMELINE_DATA.setVisibleRange(...)`) zavolat
  `TIMELINE_DATA.updateLoadedRangeBar()` → segmenty se posunou/přemapují při scrollu i zoomu.
- Na konci `initTimeline()` zavolat jednou `TIMELINE_DATA.updateLoadedRangeBar()` (inicializace geometrie,
  zprvotně celý proužek šedý).

### 5. `index.tsx` — vykreslení proužku

- Wrapperu `View.vis-timeline-wrapper` (řádky ~190–199) přidat `position: relative` do `style`.
- Hned za `<div ref={containerRef} />` vložit:

```tsx
<LoadedRangeBar
    ref={TIMELINE_DATA.loadedRangeBarRef}
    timelineRef={timelineRef}
    containerRef={containerRef}
    getLoadedRanges={TIMELINE_DATA.getLoadedDataRanges}
/>
```

`containerRef` je dostupný z `useTimelineUI(...)`, `timelineRef` je definovaný na řádku 90.

## Proč to splňuje zadání

- **Vždy viditelný při vertikálním scrollu:** proužek je absolutně pozicovaný vůči wrapperu na fixní
  `top` = spodní hrana `.vis-panel.vis-top`, která se vertikálním scrollem nehýbe.
- **Pod hodinami:** sedí přesně na švu mezi osou s hodinami a obsahem.
- **Sleduje horizontální scroll/zoom:** přepočítává segmenty z `getWindow()` při každém `rangechange`.
- **Modrá až po datech:** zdrojem je `loadedDataRangesRef`, plněný v `loadData` po doručení z API.

## Verifikace

- Typová kontrola projektu (TS build / `tsc`) — bez chyb.
- Manuální vizuální kontrola (uživatel kontroluje ručně — neautomatizovat inspektor):
  1. Spustit dev server, otevřít scheduling kalendář.
  2. Po prvním načtení: viditelné okno modré, zbytek osy šedý.
  3. Scrollovat doleva/doprava do nenačtené oblasti → proužek tam šedý, po doběhnutí fetchu zmodrá
     (souběžně se točí stávající spinner).
  4. Vertikálně scrollovat → proužek zůstává na místě pod hodinami.
  5. Zoom (Ctrl+scroll / ZoomPicker) → segmenty se správně přemapují.
  6. Změna filtru → proužek se vyresetuje na šedou a postupně modrá podle nového načítání.
