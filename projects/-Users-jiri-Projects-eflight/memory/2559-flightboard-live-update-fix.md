# Fix: Flightboard live update – zaseknutí aplikace (task #2559)

## Kontext

Hotfix `8705a3ae` odstranil live update z Scheduling Calendar a FlightboardControlButton,
aby opravil zaseknutí aplikace při příchodu live updatu. Byl revertován – problém je třeba
vyřešit systémově.

Dev helper pro simulaci: `window.__flightboardDataService.simulateLiveUpdate()` (pouze v dev módu).

## Kořenové příčiny

### 1. Listener leak (oba komponenty)

`dataService.on('update', ...)` se nikdy neodregistruje:

- `src/Admin/Scheduling/screen/Calendar/index.tsx` (řádek 271)
  – cleanup v `useDidMountEffect` volá pouze `unsubscribe()` ze subscriptions na rezervace,
  ale chybí `dataService.off(...)`.
- `src/Admin/Flightboard/screens/FlightboardControlButton.tsx` (řádek 99)
  – `initData()` přidá listener, ale cleanup vůbec neexistuje.

Důsledek: každý mount komponenty přidá nový listener. Pokud se komponenta mountuje/unmountuje
vícekrát (navigace, React StrictMode), listenery se hromadí.

### 2. N re-renderů na jeden update

V `Calendar/index.tsx` se při každém `update` eventu volá `changeFlightStatus` v loopu:

```ts
for (const item of data) {
    LEG_TIMELINE.changeFlightStatus(item); // jednou pro každou položku
}
```

Každé volání `changeFlightStatus` volá `postprocessAndPropagateChange`, které volá
`params_onTimelineDataChange` (React state update). React 17 nebatchuje state updates
mimo event handlery (EventEmitter callback), takže N položek = N synchronních re-renderů.
S větším flightboardem to aplikaci zasekne.

### 3. Dvojité volání `params_onTimelineDataChange` v `postprocessAndPropagateChange`

`postprocessAndPropagateChange` volá callback přímo A zároveň ho předává `DutyPostprocessor.process()`
jako `onAsyncComplete`, který ho zavolá znovu po dokončení async operací.

## Plán opravy

### Krok 1: Ověření reprodukce

1. Otevřít Scheduling Calendar
2. V DevTools: `window.__flightboardDataService.simulateLiveUpdate()`
3. Ověřit zaseknutí / mnoho re-renderů v React DevTools Profiler

### Krok 2: Opravit listener leak

**`Calendar/index.tsx`** – uložit referenci na listener a odregistrovat v cleanup:
```ts
useDidMountEffect(() => {
    // ...
    const onUpdate = (data: CreateFlightboardDataInput[]) => { ... };
    dataService.on('update', onUpdate);
    return () => {
        unsubscribe();
        dataService.off('update', onUpdate);
    };
});
```

**`FlightboardControlButton.tsx`** – stejný vzor v `initData()` + cleanup v `useDidMountEffect`.

### Krok 3: Eliminovat N re-renderů

Přidat do `useTimelineData` novou metodu `changeFlightStatuses` (plural), která:
- Přijme celé pole `CreateFlightboardDataInput[]`
- Projde všechny položky v jediném `items.map()`
- Zavolá `postprocessAndPropagateChange` **jednou** s výsledkem

V `Calendar/index.tsx` nahradit loop za:
```ts
dataService.on('update', (data) => {
    if (isNone(data)) return;
    LEG_TIMELINE.changeFlightStatuses(data); // nová batch metoda
});
```

### Krok 4: Ověřit fix

Spustit `window.__flightboardDataService.simulateLiveUpdate()` a ověřit:
- Žádné zaseknutí
- Pouze 1 re-render v React DevTools Profiler
- FlightboardControlButton správně reaguje na změny stavu

## Dotčené soubory

- `src/Admin/Scheduling/screen/Calendar/index.tsx`
- `src/Admin/Flightboard/screens/FlightboardControlButton.tsx`
- `src/Admin/Scheduling/screen/Calendar/LegTimeline/useTimeline/useTimelineData.tsx`
- `src/Admin/Scheduling/screen/Calendar/LegTimeline/index.tsx` (export nové metody)
