# #2640 — Dolaďování live flight updates: asymetrické prahy, CTOT priorita, skrytí FPL/CTOT po odletu

## Context

První kolo #2640 (PR #2697 + commit `3873bc988` + PR #2701) zavedlo do scheduling kalendáře live propagaci FPL/CTOT/actuals — popup, posun baru, status badge i šrafování fungují. Detekce „posunutí" (`isShifted` → žlutá `.delayed` šrafa, blink časů v baru, color v popupu) ale dnes používá **symetrický** 15min práh (`Math.abs(shift) >= 15min`) na **OR** mezi FPL a CTOT, a navíc tzv. „planned-snap" vrací phase na `scheduled`, když je posun malý.

Uživatel chce jemnější pravidla bližší reálnému dispatcher workflowu:

1. **Po odletu** (existuje `actualDeparture`) ukázat v popupu pouze `Departed` (zeleně). `FPL` a `CTOT` řádky vůbec nezobrazit, i kdyby v `flightInfo` byly.
2. **Asymetrické prahy** pro žlutou šrafu nad barem a pro obarvení FPL/CTOT/ETA v popupu: posun **> 15 min DŘÍVE** NEBO **>= 30 min POZDĚJI** než scheduled. Mezi `[-15 min, +30 min)` je leg „on time".
3. **CTOT má prioritu** pro detekci posunu — zrcadlí prioritu pro pozici baru `actualDeparture > CTOT > FPL > scheduled`. Když existuje CTOT, FPL se pro detekci ignoruje. V `inflight` fázi se posun počítá z `actualDeparture`.
4. **Arrival šrafa**: samostatná podmínka — `effectiveTimeIn − scheduledTo >= 30 min` (jednostranná, žádné „early arrival"). Aktivní v `planned` a `inflight`, v `landed` ne.
5. **Po přistání** žádná šrafa. Popup `Departed`/`Landed` zelený řádek **zachovat** (jen šrafa nad barem zmizí).
6. **Zrušit planned-snap** — bar se vždy posune na effective (i +5 min CTOT je viditelný posun). Šrafa je nezávislá podmínka; pro malé posuny bar tedy je posunutý, ale šrafa není.

## Recommended approach

### 1. `src/Admin/Flightboard/models/effectiveTimes.ts`

**Konstanty** (řádek 17): rozdělit `SHIFT_TOLERANCE_MS` na dvě, smazat původní.
```ts
export const EARLY_SHIFT_TOLERANCE_MS = 15 * 60_000; // > 15 min DŘÍVE než scheduled
export const LATE_SHIFT_TOLERANCE_MS = 30 * 60_000;  // >= 30 min POZDĚJI než scheduled
```

**Smazat planned-snap blok** (řádky 122-130 — `if (phase === 'planned' && !hasFplOrCtotShift)`). Bar zůstane na effective i pro malé posuny; phase = `planned` nebude umělě snapnuta zpět na `scheduled`.

**Refaktor `isShifted`** (řádky 117-134 → nový blok):
```ts
// Driver pro departure shift kopíruje prioritu pro pozici baru:
//   - inflight: actualDeparture - scheduledFrom
//   - planned:  (CTOT ?? FPL) - scheduledFrom  (CTOT > FPL priorita)
//   - landed / scheduled / cancelled: undefined → bez departure šrafy
let depShiftMs: number | undefined;
if (phase === 'inflight' && actualDeparture) {
    depShiftMs = actualDeparture.getTime() - scheduledFrom.getTime();
} else if (phase === 'planned') {
    const driver = ctotTime ?? fplTime;
    if (driver) depShiftMs = driver.getTime() - scheduledFrom.getTime();
}
const isDepShifted =
    depShiftMs !== undefined &&
    (depShiftMs < -EARLY_SHIFT_TOLERANCE_MS || depShiftMs >= LATE_SHIFT_TOLERANCE_MS);

// Arrival shift: ETA >= 30 min pozdě (one-sided), aktivní jen pre-landing.
const isArrShifted =
    (phase === 'planned' || phase === 'inflight') &&
    effectiveTimeIn.getTime() - scheduledTo.getTime() >= LATE_SHIFT_TOLERANCE_MS;

const isShifted = isDepShifted || isArrShifted;
```

Důsledky:
- `phase === 'landed'` → oba flagy false → `isShifted = false` → žádná šrafa (i pro hodně odchýlené actuals). ✓
- `phase === 'cancelled'` má early return na začátku funkce. ✓
- `phase === 'scheduled'` (žádné FPL/CTOT/actuals) → driver undefined, ETA = scheduledTo → oba flagy false. ✓

**`getLegTimeSlots` — gate planned blink na `isShifted`** (řádek 181-185):
```ts
case 'planned': {
    if (!eff.isShifted) {
        // Maly posun: bar je na effective, ale times nepreblikavaji - vychazi single
        // (effective) cernou barvou, konzistentni se "scheduled" vzhledem.
        return {
            out: { mode: 'single', time: eff.effectiveTimeOut },
            in: { mode: 'single', time: eff.effectiveTimeIn },
        };
    }
    return {
        out: { mode: 'blink', sched: scheduledFrom, eff: eff.ctotTime ?? eff.fplTime ?? eff.effectiveTimeOut },
        in: { mode: 'blink', sched: scheduledTo, eff: eff.effectiveTimeIn },
    };
}
```

### 2. `src/Admin/Scheduling/screen/Calendar/LegTimeline/LegPopupContent/index.tsx`

**`getEffLines` — skrýt FPL/CTOT po odletu** (řádky 304-321):
```ts
function getEffLines(eff: EffectiveTimes, side: 'left' | 'right', scheduled: Date): EffLine[] {
    if (eff.phase === 'cancelled') return [];
    if (side === 'left') {
        // Po odletu uz nas FPL/CTOT nezajimaji - ukazujeme jen Departed.
        if (eff.actualDeparture) {
            return [{ label: 'Departed', time: eff.actualDeparture, color: 'success' }];
        }
        const lines: EffLine[] = [];
        if (eff.fplTime) lines.push({ label: 'FPL', time: eff.fplTime, color: colorForShift(eff.fplTime, scheduled) });
        if (eff.ctotTime) lines.push({ label: 'CTOT', time: eff.ctotTime, color: colorForShift(eff.ctotTime, scheduled) });
        return lines;
    }
    // right - beze zmeny: Landed (zeleny) / ETA (cerny|zluty dle shiftu) / nic
    if (eff.actualArrival) return [{ label: 'Landed', time: eff.actualArrival, color: 'success' }];
    if (eff.phase === 'planned' || eff.phase === 'inflight') {
        return [{ label: 'ETA', time: eff.effectiveTimeIn, color: colorForShift(eff.effectiveTimeIn, scheduled) }];
    }
    return [];
}
```

**`colorForShift` — asymetrické prahy** (řádek 295-297):
```ts
function colorForShift(time: Date, scheduled: Date): EffLineColor {
    const diff = time.getTime() - scheduled.getTime();
    return diff < -EARLY_SHIFT_TOLERANCE_MS || diff >= LATE_SHIFT_TOLERANCE_MS ? 'warning' : undefined;
}
```

**Imports** (řádek 8-12): nahradit `SHIFT_TOLERANCE_MS` za `EARLY_SHIFT_TOLERANCE_MS` + `LATE_SHIFT_TOLERANCE_MS`.

### 3. `getItemContent.ts` a `styles.sass` — beze změny

- `.delayed` se přidává v `getItemContentPropsBasedOnData:44` na základě `eff?.isShifted === true && eff.phase !== 'cancelled'`. Po refaktoru `deriveEffectiveTimes` se `isShifted` automaticky stane false pro landed / scheduled / cancelled → šrafa zmizí. Žádná úprava CSS ani HTML rendereru.
- Pro planned + ne-shifted vrátí `getLegTimeSlots` `mode: 'single'` → HTML `<small>HH:mm</small>` (bez vnitřního `<em>`). CSS pravidlo `styles.sass:544-555` (`.phase-planned ... > small { display: inline-grid; > small ...; > em ... }`) se aplikuje s jediným text-uzlem uvnitř — vizuálně identické s default `<small>`. Pokud bude vizuální nesoulad, fallback `.phase-planned ... > small:has(> em)` (CSS standard `:has()`).

## Files to touch

1. `src/Admin/Flightboard/models/effectiveTimes.ts` — split tolerancí, smazat planned-snap, nový `isShifted` driver-priority, gate `getLegTimeSlots` 'planned' na `eff.isShifted`.
2. `src/Admin/Scheduling/screen/Calendar/LegTimeline/LegPopupContent/index.tsx` — skrýt FPL/CTOT po odletu v `getEffLines`, asymetrický `colorForShift`, update import.

**Beze změny:** `useTimeline/getItemContent.ts`, `LegTimeline/styles.sass`, `DutyPostprocessor.ts`, `FlightboardStatus.tsx`, `useTimelineData.tsx`, žádný backend (`amplify/backend/function/flightboard/...`).

## Verification

`/admin/scheduling`, leg viditelný při `width_50` (force "Min label size" → 50). Test cases přes `__flightboardDataService.simulateFlightInfo(reservationId, eventId, partial)`:

**Planned phase** (žádný `actualDeparture`):
- `{ fpl: { date: sched, source:'RR' } }` (FPL = scheduled) → bar na scheduled, dep/arr single černé, NO šrafa, NO blink.
- `{ fpl: { date: sched + 5min, source:'RR' } }` → bar +5 min, single černé (effective), NO šrafa, NO blink.
- `{ fpl: { date: sched - 10min, source:'RR' } }` → bar -10 min, single černé, NO šrafa (`-10 > -15`).
- `{ fpl: { date: sched + 30min, source:'RR' } }` → boundary: bar +30 min, BLINK scheduled↔FPL, ŠRAFA (`30 >= 30`).
- `{ fpl: { date: sched - 16min, source:'RR' } }` → bar -16 min, BLINK, ŠRAFA (`-16 < -15`).
- **CTOT priorita:** `{ fpl: { date: sched - 20min }, calculatedDeparture: { date: sched + 5min } }` → bar na CTOT (+5), single černé, NO šrafa (CTOT je v normě, FPL se ignoruje). Sanity: bez CTOT by tentýž FPL aktivoval šrafu.
- **Arrival late:** `{ fpl: { date: sched }, estimatedArrival: { date: schedTo + 45min } }` → departure on time, ale ETA +45 → ŠRAFA aktivní (arrival podmínka), BLINK obou times.

**Inflight phase** (`actualDeparture` exists, `actualArrival` neexistuje):
- `{ actualDeparture: { date: sched + 35min, source:'TLB' }, status:'InFlight' }` → bar na actual, dep ZELENÝ, arr černý (ETA), ŠRAFA (`35 >= 30`).
- `{ actualDeparture: { date: sched + 10min, source:'TLB' }, status:'InFlight' }` → bar na actual, dep zelený, NO šrafa (`10 < 30`).
- `{ actualDeparture: { date: sched - 20min, source:'TLB' }, status:'InFlight' }` → ŠRAFA (`-20 < -15`).
- Popup vlevo: pouze "Departed XX:XX" zeleně. FPL ani CTOT řádek NIKDY (i kdyby v simulaci zůstaly).

**Landed phase** (`actualArrival` exists):
- `{ actualDeparture, actualArrival, status:'Landed' }` → bar na actuals, oba times ZELENÉ, NIKDY šrafa (ani kdyby actuals byly hodně mimo scheduled).
- Popup vlevo: "Departed XX:XX" zeleně; vpravo: "Landed XX:XX" zeleně.

**Cancelled:** žádné effLines, žádná šrafa.

**Popup `colorForShift` boundary** (planned, FPL řádek):
- FPL +25 min → ČERNÁ; FPL +30 min → ŽLUTÁ.
- FPL -15 min → ČERNÁ; FPL -16 min → ŽLUTÁ.

(`eflight-visual-inspector` Playwright agent existuje, ale uživatel kontroluje vizuálně manuálně.)

## Decisions made (potvrzeno uživatelem)

- **Šrafa** = jedna `.delayed` čára přes celý bar (OR mezi departure a arrival shift). Žádný refaktor HTML/CSS struktury (žádné rozdělení na dep half + arr half).
- **Bar vždy na effective** — planned-snap zrušen. Times v planned: single effective černé (ne-shifted) NEBO blink scheduled↔effective žlutý (shifted).
- **Popup po přistání** zachovat `Departed` + `Landed` zelený řádek; šrafa nad barem zmizí.
- **Asymetrické prahy** stejné pro šrafu nad barem i pro `colorForShift` v popupu (`< -15` OR `>= 30`).
