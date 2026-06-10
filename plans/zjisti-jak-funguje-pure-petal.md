# Task #2698 — FPL možnost odpárování

## Context

V checklist FPL záložce rezervace ChildEvent v eFlight aktuálně neexistuje způsob, jak ručně odpárovat spárovaný flight plan (FPL) od legu. Auto-pairing běží na základě scoring logiky (registrace + ICAO + EOBT) v `RocketRouteSelector.tsx`.

V rámci tasku #2698 chce uživatel:

1. **Tlačítko "Unpair FPL"** pro ruční odpárování.
2. **Auto-unpair scénáře**:
   - Uživatel **mění** scheduled time odletu (`childEvent.dateFrom`) na hodnotu < FPL EOBT.
   - FPL se v RocketRoute stane `cancelled`.
3. **Zpřísněné auto-pair** podmínky, aby se nestávalo, že FPL hned po odpárování bude znovu auto-spárován.

**Souvislost s #2640 (live flight updates v kalendáři):** Bar legu v scheduling kalendáři se posouvá podle FPL/CTOT z `flightboardData`. Backend Lambda `FlightboardProcessor` páruje FPL k legu podle `rocketRouteId`. Po odpárování (`rocketRouteId = undefined`) Lambda přestane párovat → `flightInfo` se přestane aplikovat → bar se vrátí na scheduled pozici, šrafa zmizí. **"Let se vrátí kde byl" znamená jen vizuálně v kalendáři** — `dateFrom/dateTo` legu se nemění.

**Z tasku #2698 ostatní body** (rozlišení IOBT/EOBT, CDM `IOBT = SLOT/PPR`, EOBT -30/+60 červeně, backend flag) NEjsou součástí této iterace — budou v dalších PR.

## Pravidla chování (rekapitulace specifikace)

| # | Scénář | Akce |
|---|---|---|
| 1 | Klik "Unpair FPL" | `rocketRouteId → undefined`, `flightPlanData → undefined`, checklist confirmation `flightPlan` → `not_confirmed`. V aktuální session NESPUSTIT auto-pair. |
| 2 | Znovu-otevření modalu rezervace bez `rocketRouteId` | Auto-pair se spustí, ale jen pokud splní pravidlo 4 (session flag se ztratí remount-em). |
| 3 | Uživatel **mění** `dateFrom` na hodnotu < `FPL.eobt` | Auto-unpair. NESPOUŠTĚT při pouhém otevření modalu, jen při skutečné změně. |
| 4 | Zpřísněné auto-pair podmínky (pro `active`) | `aircraftRegistration` match (no fallback), `adepIcao === location` (no `ZZZZ`), `adesIcao === locationEnd`, `eobt ∈ [dateFrom, dateFrom + 1h]`, `status === 'active'`. |
| 5 | `FPL.status → 'cancelled'` | Auto-unpair (detekováno při fetch FPL detailu v UI). |
| 6 | Manuální výběr | Drží se, pokud nenastane 3) ani 5) — i pokud nesplňuje 4). |

**Draft FPL** zachová stávající logiku (score ≥ 23 v `createFlightPlanScorerForEvent`). Nová zpřísněná pravidla 4 platí jen pro `active`. Pro `draft` se auto-unpair NEspouští.

## Datový model

**Žádná nová pole** na `ChildEvent` ani v shared types. Vše se modeluje přes:

- existující `childEvent.rocketRouteId?` (FPL ID)
- existující `childEvent.flightPlanData?` (mreq, ebrn, eetMinutes)
- existující checklist confirmation `flightPlan` (přes `onConfirm`)
- **session-level `useState<boolean> unpairedThisSession`** v `FlightPlanRocketRouteTab` — žije po dobu otevřeného tab/modalu, remount ho přirozeně resetuje (splňuje pravidlo 2).

## Soubory k úpravě

- `src/Admin/Scheduling/screen/Calendar/ReservationForm/ChildEventForm/Checklist/ChecklistTable/Tabs/FlightPlanRocketRoute/FlightPlanRocketRouteTab.tsx` — session flag, prop propagace
- `src/Admin/Scheduling/screen/Calendar/ReservationForm/ChildEventForm/Checklist/ChecklistTable/Tabs/FlightPlanRocketRoute/FlightPlanDetail.tsx` — tlačítko "Unpair FPL", 2 nové `useEffect` (scénáře 3 a 5)
- `src/Admin/Scheduling/screen/Calendar/ReservationForm/ChildEventForm/Checklist/ChecklistTable/Tabs/FlightPlanRocketRoute/RocketRouteSelector.tsx` — prop `disableAutoSelect`, funkce `isAutoPairEligible`, rozdělení `active` vs `draft` cesty
- `src/Admin/Scheduling/screen/Calendar/ReservationForm/ChildEventForm/Checklist/ChecklistTable/Tabs/FlightPlanRocketRoute/FlightPlanAutoConfirmer.tsx` — skrýt "State was automatically changed" badge při unpair
- **NOVÝ** `src/Admin/Scheduling/screen/Calendar/ReservationForm/ChildEventForm/Checklist/ChecklistTable/Tabs/FlightPlanRocketRoute/unpairFlightPlan.ts` — společný helper
- `src/Admin/Scheduling/screen/Calendar/ReservationForm/ChildEventForm/Checklist/ChecklistTable/Tabs/ServiceTab.tsx` — propagace `onConfirm` do tabu (pokud ještě nepřichází)

## Návrh implementace

### 1. Helper `unpairFlightPlan.ts` (nový)

```ts
type UnpairArgs = {
    childEvent: ChildEvent;
    onEventChange: (ce: ChildEvent) => void;
    onConfirm: ConfirmButtonProps['onConfirm'];
    checklistKey: ChecklistKey; // vždy 'flightPlan'
};
export function unpairFlightPlan({ childEvent, onEventChange, onConfirm, checklistKey }: UnpairArgs) {
    onEventChange({ ...childEvent, rocketRouteId: undefined, flightPlanData: undefined });
    onConfirm({ checklistKey, status: 'not_confirmed', data: undefined, confirmMethod: 'fplSelect' });
}
```

Volá se z: manual tlačítka, useEffect scénáře 3, useEffect scénáře 5.

### 2. `FlightPlanRocketRouteTab.tsx`

```tsx
const [unpairedThisSession, setUnpairedThisSession] = useState(false);

const handleEventChange = (ce: ChildEvent) => {
    // Pokud uživatel ručně vybral FPL po unpair, reset session flag
    if (ce.rocketRouteId && unpairedThisSession) {
        setUnpairedThisSession(false);
    }
    onEventChange(ce);
};

if (!rocketRouteId) {
    return (
        <RocketRouteSelector
            autoSelectMostLikely
            disableAutoSelect={unpairedThisSession}
            childEvent={childEvent}
            onEventChange={handleEventChange}
        />
    );
}
return (
    <FlightPlanDetail
        childEvent={childEvent}
        reservation={reservation}
        rocketRouteId={rocketRouteId}
        onEventChange={handleEventChange}
        onConfirm={onConfirm}
        onUnpair={() => setUnpairedThisSession(true)}
    />
);
```

### 3. `FlightPlanDetail.tsx`

**Tlačítko vedle "Choose Different FPL"** (řádek 218–228):

```tsx
<button
    className="btn btn-sm btn-outline-danger ms-2"
    onClick={(evt) => {
        evt.preventDefault();
        unpairFlightPlan({ childEvent, onEventChange, onConfirm, checklistKey: 'flightPlan' });
        onUnpair();
    }}
>
    Unpair FPL
</button>
```

**Auto-unpair scénář 3** (změna dateFrom):

```tsx
const prevDateFromMs = usePrev(childEvent.dateFrom.getTime());
useEffect(() => {
    if (!flightplan || prevDateFromMs === undefined) return;
    if (prevDateFromMs === childEvent.dateFrom.getTime()) return;
    if (childEvent.dateFrom.getTime() < flightplan.eobt.getTime()) {
        unpairFlightPlan({ childEvent, onEventChange, onConfirm, checklistKey: 'flightPlan' });
        onUnpair();
    }
}, [childEvent.dateFrom, flightplan?.eobt, prevDateFromMs]);
```

**Auto-unpair scénář 5** (cancelled):

```tsx
useEffect(() => {
    if (flightplan?.status === 'cancelled') {
        unpairFlightPlan({ childEvent, onEventChange, onConfirm, checklistKey: 'flightPlan' });
        onUnpair();
    }
}, [flightplan?.status]);
```

### 4. `RocketRouteSelector.tsx`

```ts
function isAutoPairEligible(fpl: RocketRouteFlightPlanListData, childEvent: ChildEvent): boolean {
    const reg = normalizeAircraftRegistration(getAircraftRegistration(childEvent) ?? '');
    if (!reg || fpl.aircraftRegistration !== reg) return false;
    if (fpl.adepIcao !== childEvent.location) return false;
    if (fpl.adesIcao !== childEvent.locationEnd) return false;
    if (fpl.status !== 'active') return false;
    const eobtMs = fpl.eobt.getTime();
    const fromMs = childEvent.dateFrom.getTime();
    if (eobtMs < fromMs || eobtMs > fromMs + 3600_000) return false;
    return true;
}
```

V auto-select useEffect (řádky 52–70) přidat guard `disableAutoSelect` a rozdělit cestu pro `active` vs `draft`:

```tsx
if (childEvent.rocketRouteId) return;
if (!autoSelectMostLikely || disableAutoSelect || !scored?.length) return;

const mostLikely = scored[0];
const fpl = mostLikely.flightPlan;

const isActiveAndStrictMatch = fpl.status === 'active' && isAutoPairEligible(fpl, childEvent);
const isDraftLegacyMatch =
    fpl.status === 'draft' &&
    mostLikely.score >= 23 &&
    !(scored[1] && scored[1].score === mostLikely.score);

if (!isActiveAndStrictMatch && !isDraftLegacyMatch) return;
onEventChange({ ...childEvent, rocketRouteId: fpl.rocketRouteId });
```

`createFlightPlanScorerForEvent` (řádky 88–132) ZACHOVAT beze změny — používá se pro dropdown order při manuálním výběru.

### 5. `FlightPlanAutoConfirmer.tsx`

Stávající `useEffect` (řádky 38–54) reaguje na změnu `fplId`. Pro skrytí badge "State was automatically changed according to flight plan" po unpair přidat:

```tsx
useEffect(() => {
    if (fplId === undefined) {
        setShowNewAutostatus(undefined);
    }
}, [fplId]);
```

Reset confirmation samotný se NEdělá zde — `unpairFlightPlan` helper to udělá rovnou (single source of truth).

### 6. `ServiceTab.tsx`

Pokud `onConfirm` ještě nepřichází do `FlightPlanRocketRouteTab`, dodat propagaci (najít kde se Tab renderuje, ověřit signature).

## Edge cases

- **Loading FPL listu**: `FlightPlanDetail` (řádky 77–79) už řeší spinner. Auto-unpair `useEffect` se chrání `if (!flightplan) return`.
- **Drobná změna dateFrom (sekundy)**: scénář 3 unpaří jen pokud nová hodnota < EOBT. Změny ≥ EOBT nedělají nic.
- **Multileg**: per-leg izolace — každý leg má vlastní `FlightPlanRocketRouteTab` instance s vlastním session flag a vlastním `rocketRouteId`.
- **"Choose Different FPL" po unpair**: wrapper `handleEventChange` v `FlightPlanRocketRouteTab` resetuje session flag jakmile nový `rocketRouteId` má hodnotu.
- **První render po remount**: `usePrev` vrací `undefined` → useEffect scénáře 3 early-return na `prevDateFromMs === undefined`.

## Verifikace (E2E lokálně)

1. **Manual unpair**: otevřít rezervaci se spárovaným FPL → klik "Unpair FPL" → `rocketRouteId` zmizí (devtools), confirmation badge přejde na `not_confirmed`, selektor se objeví prázdný; **NEzvolí automaticky** (session flag).
2. **Ruční volba po unpair**: kliknout do selektoru → vybrat FPL → session flag se resetuje, FPL se spáruje, badge "State was automatically changed" se zobrazí.
3. **Re-open modalu (pravidlo 2)**: zavřít modal, otevřít znovu (bez `rocketRouteId`) → auto-pair běží podle nového scoringu (přísné podmínky pro `active`). Pokud FPL nesplňuje, selektor zůstane prázdný.
4. **Scénář 3 (změna dateFrom)**: spárovaný FPL, kde `EOBT > dateFrom` (po otevření nic) → uživatel změní `dateFrom` o 2 hodiny zpět → FPL se odpojí, confirmation reset.
5. **Scénář 4 (zpřísněné podmínky)**: ručně přidat FPL s `adepIcao = 'ZZZZ'` → unpair → zavřít/otevřít → FPL se znovu nenapáří (pravidlo 4 nesplňuje `ZZZZ`).
6. **Scénář 5 (cancelled)**: změnit status FPL na `cancelled` v RocketRoute (nebo přes test stub) → reload listu → unpair se spustí.
7. **Multileg**: unpair na legu A nezasáhne `rocketRouteId` legu B.
8. **Kalendář (souvislost #2640)**: po manuálním unpair se bar legu ve scheduling kalendáři vrátí na scheduled pozici po další iteraci Lambdy `FlightboardProcessor` (čistě backend timing, neimplementuje se zde).

## Co tento PR NEdělá

- Body 2–4 ze specifikace tasku #2698 (rozlišení IOBT/EOBT, CDM `IOBT = SLOT/PPR ± 0min` validace, EOBT -30/+60 červeně, backend flag pro automatickou aktualizaci se změnou FPL) — budou v dalších iteracích.
- Backend změny (Lambda `FlightboardProcessor`) — `rocketRouteId = undefined` Lambda už dnes přirozeně přestane párovat, žádný explicit cleanup `flightboardData` není potřeba (Lambda běží periodicky a kompenzuje).
- Testy (per memory `feedback_no_tests`).
