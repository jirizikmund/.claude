# #2640 Live flight updates v scheduling

## Kontext

Scheduling kalendář (`LegTimeline`) dnes přebírá z Flightboard live updaty pouze `FlightStatus` (enum). GitHub issue **#2640** (HIGH PRIORITY, assignees veproza + jirizikmund) požaduje, aby se do scheduling propagovaly i časy: **FPL, CTOT, actualDeparture, actualArrival**, a aby se podle nich:

1. **Zobrazovaly v hover popupu nad legem** — pod local times v zelené barvě, CTOT žlutě uprostřed.
2. **Posouval bar v časové ose** kalendáře.
3. **Přepočítávala duty norma** v scheduling kalendáři.

### Priorita časů (klíčový komentář od jirizikmund 2026-04-17)

```
actualDeparture > calculatedDeparture (CTOT) > fpl > scheduled
```

A pro arrival: `actualArrival → landed` (final) > derived z effective departure + flight time. Cancelled letadlo se neposouvá (zůstává scheduled).

### Past hotfix jako precedent

Commit `8705a3ae2 "Remove live flight update from scheduling - hotfix"` byl revertnut, ale dokumentuje že se fenomén live updateu už jednou rolloval. Stejný rollback vzor (zakomentovat `dataService.on('update', …)` v `Calendar/index.tsx`) zůstává jako jednoznačné quick-revert tlačítko.

---

## Souhrn z uživatelského pohledu

### Co dispečer uvidí

**Před vzletem (planned), 24h před scheduled time, podán FPL:**
- Bar legu se v kalendáři posune na **FPL time** (pokud existuje), případně dál na **CTOT time** (CTOT vyšší priorita než FPL).
- Bar dostane vizuální indikaci "Delayed" (např. dashed border) pokud je posun ≥ 1 minuta.
- V hover popupu pod řádkem local time přibude **zelený řádek**:
  - `ETD HHmmZ` na levé straně (departure airport).
  - `ETA HHmmZ` na pravé straně (arrival airport).
  - Mezi nimi pokud existuje CTOT: `ETD 1320Z CTOT 1344Z` (CTOT žlutě).

**Po vzletu (inflight):**
- Bar se posune na **actual takeoff time**, end = takeoff + flight time dle FPL.
- Třída `inflight` (volitelně blikající ikonka letadla — UX polish PR).
- Popup: vlevo `Departed HHmmZ` (zelené), vpravo `ETA HHmmZ`.

**Po přistání (landed):**
- Bar = actualDeparture..actualArrival (skutečná délka letu).
- Třída `landed`.
- Popup: vlevo `Departed HHmmZ`, vpravo `Landed HHmmZ`.

**Cancelled leg:**
- Bar zůstává na scheduled, žádný posun, žádný "Delayed" indicator. (Invariant.)

### Dopad na duty/normu

Duty calculation v scheduling kalendáři (FDP, rest, blok, errory na pilotových řádcích) se počítá z **effective times** — tedy actual/CTOT/FPL místo scheduled. Takže pokud let zpozdil na CTOT, dispečer uvidí přesnější duty preview. Po přistání duty odpovídá skutečnosti.

Mimo scheduling kalendář (Welcome screen schedule preview, Admin Duty screen, DutyPeriodForm editor, Reservation form Duty Preview) zůstává chování beze změny — počítá se ze scheduled. Tito konzumenti nemají k flightInfo přístup ani by neměl smysl ho mít (Welcome řeší budoucí lety, editor je pro plánování).

---

## Souhrn z technického pohledu

### Datový tok dnes

```
GraphQL onUpdate subscription → Flightboard.subscribeToFlightboardData
  → DataService.subscribeToDbChanges (dataStream.ts:58-76)
  → emit('update', CreateFlightboardDataInput[])
  → Calendar/index.tsx:278-284  onFlightboardUpdate
  → LEG_TIMELINE.changeFlightStatuses (useTimelineData.tsx:160-194)
  → extrahuje POUZE update.state (FlightStatus enum), zbytek ignoruje
```

`CreateFlightboardDataInput.flightboardData` je **JSON-stringified `FlightInfo`** s poli `fpl`, `calculatedDeparture` (CTOT), `actualDeparture`, `estimatedArrival`, `actualArrival`. Pole subscription **vrací**, ale init query je ignoruje (viz blocker níže).

### Kritický blocker

**`listFlightboardStates` query** v `src/Admin/Flightboard/Datasources/Flightboard.ts:320-349` **nevrací `flightboardData` field**. Po prvním `dataService.init()` má service v paměti pouze `id, state, reservationId, eventId, eventType` — žádný `FlightInfo` JSON. Bez opravy query by `getFlightInfo()` vracel `undefined` až do prvního subscription updatu, takže scheduling kalendář by při loadu používal jen scheduled times. **Fix patří do PR1**, protokol `onCreateFlightboardData` a `onUpdateFlightboardData` už `flightboardData` vracejí.

### Architektura změny

#### A. Nová utility `deriveEffectiveTimes`

Cesta: `src/Admin/Flightboard/models/effectiveTimes.ts` (NEW).

```ts
export type EffectiveTimes = {
    effectiveTimeOut: Date;
    effectiveTimeIn: Date;
    phase: 'scheduled' | 'planned' | 'inflight' | 'landed' | 'cancelled';
    fplTime?: Date;
    ctotTime?: Date;
    actualDeparture?: Date;
    actualArrival?: Date;
    flightTimeMs: number;
    isShifted: boolean;  // ≥ 1 min diff vs scheduled
};

export function deriveEffectiveTimes(
    scheduledFrom: Date,
    scheduledTo: Date,
    flightInfo: FlightInfo | undefined,
    isCancelled: boolean,
): EffectiveTimes;
```

Pravidla aplikace (priorita):
- `isCancelled` → phase `cancelled`, effective = scheduled (bez posunu).
- `flightInfo.actualArrival.date` → phase `landed`. effectiveOut = actualDeparture ?? scheduledFrom; effectiveIn = actualArrival.
- `flightInfo.actualDeparture.date` → phase `inflight`. effectiveOut = actualDeparture; effectiveIn = actualDeparture + flightTimeMs.
- `flightInfo.calculatedDeparture.date` (CTOT) → phase `planned`. effectiveOut = CTOT; effectiveIn = CTOT + flightTimeMs.
- `flightInfo.fpl.date` → phase `planned`. effectiveOut = FPL; effectiveIn = FPL + flightTimeMs.
- jinak → phase `scheduled`, effective = scheduled.

`flightTimeMs = scheduledTo - scheduledFrom` (issue: "ETA = ETD + cas letu dle FPL"). Pro `landed` je effectiveIn = actualArrival přímo, ne přes flightTimeMs.

#### B. `dataService.getFlightInfo()` + DEV simulator

V `src/Admin/Flightboard/Datasources/dataStream.ts`:
- `getFlightInfo(reservationId, eventId): FlightInfo | undefined` s **WeakMap** parse cache klíčovanou na `CreateFlightboardDataInput` objekt. Když `subscribeToDbChanges` nahradí item novým objektem (`this.data[i] = {...}`), cache se sama invaliduje.
- DEV helper `simulateFlightInfo(reservationId, eventId, partial)` — zmerguje partial FlightInfo do existujícího `flightboardData`, vytvoří nový objekt v `this.data` (pro WeakMap cache miss), a emituje `update` event.

#### C. Rozšíření `DataItemExtendedDataChildEvent`

V `src/Admin/Scheduling/screen/Calendar/LegTimeline/types.ts:47-54` přidat `flightInfo: FlightInfo | undefined`. Item pak nese parsed FlightInfo přímo (LegPopupContent dostane v props).

#### D. `childEventToFlightLegLike(childEvent, reservation, flightInfo?)` — backward-compat

V `src/Admin/Scheduling/screen/Calendar/ReservationForm/ReservationDuties/calendarDuties.ts:24` přidat 3. parametr `flightInfo?: FlightInfo` (optional). Pokud je předán, `timeOut`/`timeIn` se počítají přes `deriveEffectiveTimes`. Bez parametru → fallback na scheduled (bezpečné).

Backward-compat konzumenti volaní BEZ flightInfo (nezměněný kód, fallback na scheduled, žádný regres):
- `DutyPeriodFormUtils.ts` (Admin Duty / DutyPeriodForm)
- `useScheduleDutyIssues.ts` (Welcome screen)
- `getReservationDuty()` v `calendarDuties.ts:13` (Reservation form Duty Preview)

Modifikovat pouze:
- `DutyPostprocessor.ts:107` — předat `item.data.flightInfo` jako 3. parametr.

---

## Implementační kroky (PR-friendly)

## Závislosti mezi PR (rychlý přehled)

| PR | Závisí na | Lze samostatně do produkce? |
|----|-----------|----------------------------|
| PR1 (Datový základ) | žádné | **ANO**, sám o sobě, žádný UI ani logical dopad |
| PR2 (Posun baru) | PR1 | ANO po PR1 — bary se posunou, ale popup ještě neuvidí ETD/CTOT, duty zůstává na scheduled |
| PR3 (Popup ETD/CTOT) | PR1, PR2 | ANO po PR1+PR2 — popup ukáže časy, duty ještě scheduled |
| PR4 (Duty propagace) | PR1, PR2 | ANO po PR1+PR2 — duty se přepočítává podle effective |
| PR5 (UX polish) | PR1–PR4 | ANO po předchozích — blikání, 24h gate, vizuální dotahování |

Každý PR po předchozí merge je **independent ship** — klient může potvrdit funkčnost, teprve pak shipuje další.

---

### PR 1 — Datový základ (žádný UI dopad)

| # | Soubor | Akce |
|---|--------|------|
| 1.1 | `src/Admin/Flightboard/Datasources/Flightboard.ts:320-349` | Přidat `flightboardData` do `listFlightboardStates` query items selection. |
| 1.2 | `src/Admin/Flightboard/models/effectiveTimes.ts` (NEW) | Utility `deriveEffectiveTimes` dle kontraktu. Plus `safeParseFlightInfo(json)` helper. |
| 1.3 | `src/Admin/Flightboard/Datasources/dataStream.ts` | `getFlightInfo()` + WeakMap cache + DEV `simulateFlightInfo`. |

**Lze samostatně do produkce?** **ANO.** Toto je čistá příprava infrastruktury:
- Query rozšíření vrací větší payload (~200 KB navíc na init při ~100 aktivních letech), ale field `flightboardData` se nikde nečte.
- `deriveEffectiveTimes` utility není zatím nikde voláno (mrtvý kód).
- `getFlightInfo()` metoda přidána, ale nikde volána.
- `simulateFlightInfo` je v DEV bloku — v produkci se nezbuilduje.
- **0% UI dopad, 0% chování pro uživatele.**

**Lokální verifikace PR1** (developer):
1. `pnpm dev` (nebo build script projektu).
2. Otevřít `/admin/flightboard` v dev konzoli:
   ```js
   __flightboardDataService.getData()[0]
   ```
   → ověřit, že nový field `flightboardData` obsahuje JSON string s FlightInfo.
3. Test simulator:
   ```js
   const x = __flightboardDataService.getData()[0];
   __flightboardDataService.simulateFlightInfo(x.reservationId, x.eventId,
       { fpl: { date: new Date(Date.now() + 30*60*1000), source: 'EF' } });
   __flightboardDataService.getFlightInfo(x.reservationId, x.eventId);
   ```
   → metoda vrátí FlightInfo s nově přidaným fpl.
4. Otevřít `/admin/scheduling` — ověřit, že kalendář funguje stejně jako předtím (žádná regrese).
5. TypeScript build čistý: `pnpm tsc` (žádné nové errory).

**Klientský verifikační scénář PR1** (po deploy do produkce):
```
Tento PR neobsahuje žádnou novou viditelnou funkci, je to jen technická příprava
pro následující funkce. Prosím prověř:

1. Otevři Scheduling kalendář — všechny lety, časy, duty errory se zobrazují stejně
   jako dříve.
2. Otevři Flightboard — všechny lety se zobrazují stejně, status updaty fungují
   (změň status u letu a ověř, že se aktualizuje).
3. Reservation form, Welcome screen, Admin Duty — vše beze změny.

Pokud nic z toho neporušilo, můžeme pokračovat dalším PR (posun baru v kalendáři).
```

---

### PR 2 — Posun baru + cancelled invariant (první viditelná funkce)

| # | Soubor | Akce |
|---|--------|------|
| 2.1 | `src/Admin/Scheduling/screen/Calendar/LegTimeline/types.ts:47-54` | Přidat `flightInfo: FlightInfo \| undefined` do `DataItemExtendedDataChildEvent`. |
| 2.2 | `src/Admin/Scheduling/screen/Calendar/LegTimeline/useTimeline/useTimelineData.tsx:601-646` | V `getDataItemsFromReservationForOneResource` načíst `dataService.getFlightInfo()`, spočítat `eff = deriveEffectiveTimes(...)`, použít `eff.effectiveTimeOut/In` pro `start`/`end`. Reusovat `isCancelled` (už počítáno na ř. 602). |
| 2.3 | `useTimelineData.tsx:160-194` | `changeFlightStatuses` safe-parsuje `flightboardData`, aplikuje `deriveEffectiveTimes`, updatuje `start`, `end`, `flightInfo`, `flightStatus`. |
| 2.4 | `useTimelineData.tsx:125-158` | `changeFlightStatus` (single update) — analogicky pro symetrii. |
| 2.5 | `getItemContent.ts:38-101` | Přidat optional `eff` parametr. Pokud `eff?.isShifted && phase !== 'cancelled'` → CSS class `delayed`. Pro `phase === 'inflight'/'landed'` analogicky. V baru zobrazit effective HH:mm pokud je posun. |
| 2.6 | `styles.sass` | Přidat `.delayed`, `.inflight`, `.landed` styly. |

**Lze samostatně do produkce?** **ANO** (po PR1). Letadla bez `flightInfo` (drtivá většina krom právě aktivních) se chovají identicky jako dnes. Aktivní letadla s `actualDeparture`/`fpl`/`CTOT` budou v kalendáři posunutá podle priority. Popup ještě neukáže ETD/CTOT (PR3), duty ještě počítá ze scheduled (PR4).

**Lokální verifikace PR2** (developer):
1. Na `/admin/scheduling` najít aktivní let v dev konzoli:
   ```js
   const x = __flightboardDataService.getData().find(d => d.reservationId);
   ```
2. **Test FPL posun:**
   ```js
   __flightboardDataService.simulateFlightInfo(x.reservationId, x.eventId,
       { fpl: { date: new Date(Date.now() + 30*60*1000), source: 'EF' } });
   ```
   → Bar v kalendáři se posune o 30 min, dostane `delayed` styl.
3. **Test CTOT priority** (CTOT > FPL):
   ```js
   __flightboardDataService.simulateFlightInfo(x.reservationId, x.eventId,
       { calculatedDeparture: { date: new Date(Date.now() + 45*60*1000), source: 'RR' } });
   ```
   → Bar se posune na CTOT (ne FPL).
4. **Test inflight:**
   ```js
   __flightboardDataService.simulateFlightInfo(x.reservationId, x.eventId,
       { actualDeparture: { date: new Date(), source: 'RR' } });
   ```
   → Bar od actualDeparture, `inflight` třída.
5. **Test landed:**
   ```js
   __flightboardDataService.simulateFlightInfo(x.reservationId, x.eventId,
       { actualArrival: { date: new Date(Date.now() + 60*60*1000), source: 'RR' } });
   ```
   → Bar = actualDeparture..actualArrival, `landed` třída.
6. **Cancelled invariant**: u zrušené rezervace simuluj actualDeparture → bar musí zůstat na scheduled, žádný `delayed`.
7. **Idempotency check**: po `simulateFlightInfo` ověř v React DevTools, že se scheduling nepořád nerendruje (memory leak / infinite loop check). Zkus 3× rychle za sebou — žádný spam.
8. **Mimo scope test**: Welcome screen + Admin Duty + Reservation Duty Preview — beze změny.

**Klientský verifikační scénář PR2** (po deploy do produkce):
```
Tento PR posouvá bary letů v Scheduling kalendáři podle reálných časů z Flightboardu.

1. Najdi v kalendáři let, který má v Flightboardu vyplněný FPL time (ale ještě
   neodletěl). Bar v kalendáři by měl být posunut na FPL time místo scheduled,
   s vizuální indikací "Delayed".

2. Najdi let, který je v provozu (actualDeparture vyplněn). Bar by měl začínat
   na actual takeoff time, s vizuálním stavem "inflight".

3. Najdi let, který už přistál (actualArrival vyplněn). Bar by měl ukazovat
   skutečnou délku letu (od takeoff po landing), stav "landed".

4. Najdi zrušený let (Cancelled rezervace). Bar musí zůstat na původním
   scheduled time — neposouvá se podle Flightboardu.

5. Hover popup zatím ukazuje stejné info jako dříve (ETD/CTOT přijde v dalším PR).

6. Duty errory na pilotových řádcích jsou počítány stále podle scheduled
   (přepočet podle skutečných časů přijde v PR4).

Pokud bary se posouvají správně podle priority "actualArrival > actualDeparture
> CTOT > FPL > scheduled" a cancelled lety zůstávají na scheduled, můžeme
pokračovat PR3 (popup s ETD/CTOT).
```

---

### PR 3 — Hover popup ETD/CTOT/Departed/Landed

| # | Soubor | Akce |
|---|--------|------|
| 3.1 | `src/Admin/Scheduling/screen/Calendar/LegTimeline/LegPopupContent/index.tsx` | V root komponentě recompute `eff = deriveEffectiveTimes(itemData.childEvent.dateFrom, ..., itemData.flightInfo, isCancelled)`. |
| 3.2 | `LegPopupContent` — `Location` (ř. 230-263) | Pod local time přidat zelený řádek dle phase: planned → "ETD HHmmZ"/"ETA HHmmZ"; inflight → "Departed HHmmZ"/"ETA HHmmZ"; landed → "Departed HHmmZ"/"Landed HHmmZ". |
| 3.3 | `LegPopupContent` — centrální blok (ř. 71-136) | Pokud `eff.phase === 'planned' && eff.ctotTime`: zobrazit `ETD HHmmZ CTOT HHmmZ` (CTOT žlutě). |

**Lze samostatně do produkce?** **ANO** (po PR1+PR2). Mění jen popup. Bary už jsou posunuté z PR2.

**Lokální verifikace PR3** (developer):
1. Pro každou fázi z PR2 (FPL, CTOT, inflight, landed) hover nad legem:
   - **FPL only**: popup pod local time vlevo "ETD HHmmZ" zeleně, vpravo "ETA HHmmZ" zeleně.
   - **FPL + CTOT**: navíc uprostřed popupu "ETD 1320Z CTOT 1344Z" (CTOT žlutě).
   - **CTOT only**: vlevo "ETD HHmmZ" (= CTOT) zeleně, vpravo "ETA HHmmZ" zeleně, žádné CTOT label uprostřed (jen jeden zelený údaj).
   - **inflight**: vlevo "Departed HHmmZ" zeleně, vpravo "ETA HHmmZ".
   - **landed**: vlevo "Departed HHmmZ", vpravo "Landed HHmmZ".
2. **Cancelled leg** popup — bez ETD/ETA řádků (zůstává jen scheduled jako dnes).
3. **Letadlo bez flightInfo** — popup beze změny (jen scheduled).

**Klientský verifikační scénář PR3** (po deploy do produkce):
```
Tento PR přidává do hover popupu nad legem v Scheduling kalendáři informace
o reálných časech.

1. Hover nad letem, který má FPL time:
   - Vlevo (departure airport) pod local time uvidíš zelený řádek "ETD HHmmZ"
   - Vpravo (arrival airport) zelený "ETA HHmmZ"

2. Hover nad letem, který má FPL i CTOT:
   - Stejné zelené ETD/ETA jako výše
   - Uprostřed popupu navíc "ETD 1320Z CTOT 1344Z" — kde CTOT je žlutě

3. Hover nad letem v provozu (actualDeparture):
   - Vlevo "Departed HHmmZ" zeleně
   - Vpravo "ETA HHmmZ" (= actual takeoff + flight time)

4. Hover nad letem po přistání:
   - Vlevo "Departed HHmmZ"
   - Vpravo "Landed HHmmZ"

5. Hover nad zrušeným letem nebo letem bez Flightboard dat:
   - Popup vypadá stejně jako dříve, žádné nové řádky

Po potvrzení můžeme pokračovat PR4 (přepočet duty norem podle skutečných časů).
```

---

### PR 4 — Duty calculation propagace

| # | Soubor | Akce |
|---|--------|------|
| 4.1 | `src/Admin/Scheduling/screen/Calendar/ReservationForm/ReservationDuties/calendarDuties.ts:24-45` | Rozšířit `childEventToFlightLegLike(childEvent, reservation, flightInfo?)`. Pokud `flightInfo` → `deriveEffectiveTimes` pro `timeOut`/`timeIn`. |
| 4.2 | `src/Admin/Scheduling/model/Duty/DutyPostprocessor.ts:107` | Předat `item.data.flightInfo` jako 3. parametr. |

**Lze samostatně do produkce?** **ANO** (po PR1+PR2). Mění duty výpočet **pouze v scheduling kalendáři** přes `DutyPostprocessor`. Welcome / Admin Duty / DutyPeriodForm / Reservation Duty Preview zůstávají na scheduled (žádný regres) — backward-compat přes optional 3. parametr.

**Lokální verifikace PR4** (developer):
1. Najdi pilota s aktivním letem v scheduling kalendáři. Poznamenat existující duty errory (pokud nějaké).
2. Simuluj actualDeparture posunuté o ≥1 hodinu:
   ```js
   __flightboardDataService.simulateFlightInfo(x.reservationId, x.eventId,
       { actualDeparture: { date: new Date(scheduled + 60*60*1000), source: 'RR' } });
   ```
   → Duty errory na pilotových řádcích se přepočítají; FDP/rest/blok by měly reflektovat posun.
3. **Idempotency**: opakovaně simuluj — duty se nesmí spamovat (žádný infinite loop).
4. **Welcome screen** (`/welcome` pokud relevantní route) — schedule preview duty issues nezměněné.
5. **Admin Duty / DutyPeriodForm** — beze změny.
6. **Reservation form Duty Preview tabulka** — beze změny (`getReservationDuty` bez flightInfo).
7. **Cancelled leg** — duty počítáno ze scheduled (cancelled invariant).

**Klientský verifikační scénář PR4** (po deploy do produkce):
```
Tento PR propaguje reálné časy z Flightboardu do výpočtu duty norem
v Scheduling kalendáři.

1. Najdi pilota s letem, který se zpozdil (actualDeparture o významný čas).
   Na jeho řádku v kalendáři by se měly duty errory/warningy přepočítat
   podle skutečného takeoff (např. změna FDP, rest period overlap).

2. Najdi let, který má posunutý FPL/CTOT — duty errory pilota by měly
   reflektovat plánovaný posun.

3. Po přistání (actualArrival) — duty by mělo odpovídat skutečné délce letu.

4. ZÁSADNÍ KONTROLA NA OSTATNÍCH MÍSTECH (NESMÍ SE ZMĚNIT):
   - Welcome screen (úvodní obrazovka) — schedule preview se chová stejně
     jako dříve (počítá ze scheduled).
   - Admin → Duty editor — beze změny.
   - V Reservation modálu Duty Preview tabulka — beze změny (počítá
     ze scheduled, určeno pro plánování).

5. Cancelled lety — duty počítáno ze scheduled, neposouvá se.

Pokud duty na pilotech v kalendáři se přepočítává podle reálných časů
a ostatní místa (Welcome, Admin Duty, Reservation Duty Preview) zůstávají
na scheduled, můžeme pokračovat PR5 (UX polish).
```

---

### PR 5 — UX polish (volitelné, po feedbacku)

| # | Položka | Detail |
|---|---------|--------|
| 5.1 | Blikající ikonka přistávání | Pro `phase === 'planned' && estimatedArrival - now < 30min` blink animace. Sjednotit s `FlightboardStatus.tsx:103-111` (existující blink pro ArrivalIn30Minutes/15Minutes). |
| 5.2 | 24h gate pro `phase: 'planned'` | Issue: "ETD a ETA se zobrazí 24h předem pokud je podán FPL". Aplikovat v `deriveEffectiveTimes` jen pro planned (FPL/CTOT), ne pro inflight/landed. |
| 5.3 | Vizuál `delayed` třídy | Tweak po feedbacku klienta z PR2 — přesný styl (border, background, badge). |
| 5.4 | Volitelně: Reservation Duty Preview live | Pokud klient požádá, rozšířit `getReservationDuty` o flightInfo lookup → live duty v reservation modálu. |

**Lze samostatně do produkce?** **ANO** (po PR1–PR4). Pure UX vylepšení, žádný funkční dopad.

**Lokální verifikace PR5** (developer):
1. Blikání: hover přes letadlo s `estimatedArrival` cca za 25 min → bar bliká.
2. 24h gate: simuluj FPL pro let za >24h → ETD/ETA řádek v popupu se nezobrazí.
3. `delayed` styl: vizuální kontrola po finálním tweaku.

**Klientský verifikační scénář PR5** (po deploy do produkce):
```
Tento PR dotahuje vizuální detaily.

1. Letadlo, které přistává do 30 min — ikonka v baru bliká.
2. Letadlo s FPL víc než 24h předem — ETD/ETA v popupu se nezobrazuje
   (zobrazí se až 24h před scheduled).
3. Vizuál "Delayed" indikace — odpovídá tomu, na čem jsme se domluvili
   v PR2.
```

---

## Rizika

### UI rizika (mírná)

- **vis-timeline `setItems` rerender** — porovná items po `id`, updatuje `start`/`end` na místě. Smooth animace, ne flash.
- **Drag/drop** — LegTimeline má `editable: { add: true }` only, žádný drag. Žádný konflikt s posunem.
- **Stack/overlap** — `stack: false`, takže posun může vizuálně překrýt sousední item. Není to data corruption, jen vizuální. **Akceptovatelné.**
- **Click handling** — kliknutí na bar otevírá reservation modal podle `data.reservation.id`. Nezávisí na `start`/`end`.
- **Reservation modal otevřený nad legem v okamžiku updatu** — modal pracuje s scheduled `childEvent.dateFrom/dateTo`, naše změna se neprojeví v editoru. Správně.

### Duty rizika (střední, nutno verifikovat při testu)

- **`DutyPostprocessor.process` idempotency** — má check přes `serializeErrors` (ř. 144) a `Object.assign(item, newData)` (ř. 147). Pokud naše změna `flightInfo` vyvolá změnu duty errors, postprocesor proběhne → správně. Pokud `getItemContentPropsBasedOnData` vrací nestabilní content, hrozí infinite loop. **Verifikovat při testu**: scheduling se po `simulateFlightInfo` nesmí spamovat rerendery. (Reálně očekáváme stabilní výstup, protože content závisí na deterministickém `eff`.)
- **`addBetweens`** — gaps se přepočítávají z `item.start/end`. Posun item.end → posun gap → nové between item ID. Ověřit že `mergeTimelineDataAndAddBetweens` (`uniqBy id`) nemá duplicate (předchozí between by měla být odstraněna v `withoutBetweensAndRoster` pre-step).
- **Welcome / Admin Duty / Reservation Duty Preview** — bez `flightInfo` → fallback na scheduled. **Žádný regres**, ale je třeba potvrdit při verifikaci PR4.

### Performance (nízké)

- **WeakMap cache** — `JSON.parse` 1× per item. Při ~100 letech a live updatech každých pár sekund negligible.
- **`changeFlightStatuses` complexity** — O(N) per update, stejně jako dnes. Nepřidáváme overhead krom cached parsování.
- **Plný timeline rerender** v postprocesoru je už dnes. Žádný regres.

### Edge cases

- **Chybějící FPL ale existující CTOT** — `eff.effectiveTimeOut = ctot ?? fpl`. UI ukáže jen CTOT (žlutě) nebo jen ETD (zeleně) podle dostupnosti.
- **Existující actualDeparture, chybějící actualArrival** — phase `inflight`, effectiveIn = actualDeparture + flightTimeMs.
- **`flightInfo` parsing fail** — safe-parse vrátí `undefined` → fallback na scheduled.
- **Posun přes půlnoc / přes timezone change** — `Date` instance, vis-timeline si poradí. UTC formát zachován.
- **Cancelled invariant** — testovat explicitně.

### Co NEMŮŽE rozbít push do master

- PR1 je no-op pro UI (jen rozšiřuje query a přidává unused metodu + DEV helper). Bezpečné mergnout sám o sobě.
- PR2 mění UI jen pro lety s reálným `flightInfo`. Letadla bez flightInfo (drtivá většina v daném okamžiku — všechno krom aktivních) se chová identicky jako dnes.
- Všechny změny duty calc jsou backward-compat přes optional 3. parametr — Welcome, Admin Duty, DutyPeriodForm, Reservation Duty Preview neovlivněny.

### Co BY MOHLO rozbít

- **Pokud `DutyPostprocessor` nemá idempotenci** se změnami `flightInfo` (infinite loop). Verifikovat manuálně v dev tools před mergnutím PR4.
- **`addBetweens` duplicate ID** po posunu (low likelihood, ale ověřit).
- **Backend cost** rozšířené `listFlightboardStates` query — payload na init bude větší. Velikost odhad: 100 aktivních letů × ~2 KB FlightInfo JSON = 200 KB. Akceptovatelné, ale pokud je provoz s tisíci aktivních flightboardData rows na PROD, může to být znát. **Doporučuji změřit** v staging před PROD pushem.

### Rollback

- **Quick rollback (≤ 5 min)**: zakomentovat `dataService.on('update', onFlightboardUpdate)` v `Calendar/index.tsx:284`. Live updaty se vypnou, bary po loadu zůstanou na effective (počítané v PR2 v init), ale dál se neaktualizují. Pokud chceme úplný rollback init-time výpočtu: revertovat v `useTimelineData.tsx:601-646` zpět na `start: childEvent.dateFrom, end: childEvent.dateTo`.
- **Granular rollback**: každá PR (1-4) je samostatně revertovatelná. PR1 může zůstat i po revertu UI změn (no-op).
- **Feature flag (volitelně)**: `import.meta.env.VITE_ENABLE_LIVE_FLIGHT_UPDATES === 'false'` v Calendar/index.tsx, vypne onFlightboardUpdate. Lze přidat v PR2.

---

## Otevřené otázky pro klienta

1. **24h gate pro FPL/CTOT v UI** — issue zmiňuje "ETD a ETA se zobrazí 24h předem pokud je podán FPL". Aplikuje se gate jen na `phase: 'planned'` (FPL/CTOT), nebo i na inflight/landed? **Doporučení: gate pouze na `planned`.**
2. **Vizualizace "Delayed"** — dashed border? Změna pozadí? Badge? Aktuálně placeholder CSS class.
3. **Blikající "přistává" ikona** — kdy přesně? `eff.effectiveTimeIn - now < 30min`? Nebo signál z `FlightStatus.ArrivalIn30Minutes`? Sjednotit s `FlightboardStatus.tsx`.
4. **Duty Preview v reservation form modalu** (`ReservationDutySection`) — chce klient i tady živé updaty? Bez explicitního požadavku necháme scheduled.
5. **Koordinace s @veproza** — existuje další konzument duty calc ze scheduling state mimo kalendář (rostering, payroll, reporting)? Hledáním `FinishedFlightLegLikeSource.scheduling` nebyl nalezen mimo Welcome/Admin Duty/DutyPeriodForm/ReservationDuty (žádný z nich nemá flightInfo přístup, OK). Potvrdit s @veproza.
6. **Backend payload size** — měřit v staging, zda rozšířená `listFlightboardStates` query nesnižuje load latency.

---

## Critical Files

- `/Users/jiri/Projects/eflight/src/Admin/Flightboard/Datasources/Flightboard.ts` (PR1: query)
- `/Users/jiri/Projects/eflight/src/Admin/Flightboard/Datasources/dataStream.ts` (PR1: getFlightInfo + simulator)
- `/Users/jiri/Projects/eflight/src/Admin/Flightboard/models/effectiveTimes.ts` (PR1: NEW utility)
- `/Users/jiri/Projects/eflight/src/Admin/Scheduling/screen/Calendar/LegTimeline/types.ts` (PR2: typ)
- `/Users/jiri/Projects/eflight/src/Admin/Scheduling/screen/Calendar/LegTimeline/useTimeline/useTimelineData.tsx` (PR2: integrace)
- `/Users/jiri/Projects/eflight/src/Admin/Scheduling/screen/Calendar/LegTimeline/useTimeline/getItemContent.ts` (PR2: bar content + class)
- `/Users/jiri/Projects/eflight/src/Admin/Scheduling/screen/Calendar/LegTimeline/styles.sass` (PR2: CSS)
- `/Users/jiri/Projects/eflight/src/Admin/Scheduling/screen/Calendar/LegTimeline/LegPopupContent/index.tsx` (PR3: popup)
- `/Users/jiri/Projects/eflight/src/Admin/Scheduling/screen/Calendar/ReservationForm/ReservationDuties/calendarDuties.ts` (PR4: legLike)
- `/Users/jiri/Projects/eflight/src/Admin/Scheduling/model/Duty/DutyPostprocessor.ts` (PR4: pass flightInfo)
