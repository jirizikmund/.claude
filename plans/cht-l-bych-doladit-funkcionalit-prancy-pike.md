# Skrýt roster popisky u letadel mimo roster

## Context

Scheduling kalendář (`/ops/`) dnes u každého letadla v `aircraftGroups` kreslí pro každý den viewport buď:
- překryv „PIC/FO: Příjmení" (když je v rosteringu přiřazená crew), nebo
- červený text „NO SCHEDULED CREW" (když crew na daný den chybí).

Logika je v `getRosterStatusItems.ts` (smyčka `for (const group of aircraftGroups)` na ř. 282–355). Smyčka nerozlišuje mezi letadlem, které je **v rosteringu zařazeno** (typicky AOC flotila), a letadlem, které **v rosteringu vůbec není** (ATO/školní/Cirrusové apod.). Proto se i u netázaných letadel zobrazuje „NO SCHEDULED CREW" na každý den, což je vizuálně rušivé a matoucí.

Cíl: u letadel, která nepatří do žádného aktivního rosteru typu `crewRoster`, se v kalendáři nemá generovat ani `roster-aircraft-crew`, ani `roster-no-crew` item — řádek zůstane bez roster překryvu.

## Zdroj pravdy o přináležitosti letadla do rosteru

- Entita `Roster` (tabulka DB Roster) drží v poli `data: RosterData` pole `aircraftIds: string[]` — viz `src/Admin/Rostering/types.ts:310-315` a normalizace v `src/Admin/Rostering/roster.ts:41`.
- Letadlo je „v rosteru", pokud je zahrnuto v `aircraftIds` alespoň jednoho aktivního (ne-`removed`) rosteru typu `crewRoster`.
- GraphQL: `rosterFields` (`src/Admin/Rostering/data.ts:28-42`) už obsahuje `data`, takže payload je přes `listRosters` dostupný bez dalšího schema změn; aktuální `listRosterNamesQuery` (ř. 125-145) pole `data` nevrací a je potřeba ho přidat.

## Změny

### 1. `src/Admin/Rostering/rosteringQueryUtils.ts`
- Rozšířit `ListRosterNamesResult` typ a `listRosterNamesQuery` v `data.ts` (resp. nahradit selector v `listRosterNamesQuery` tak, aby obsahoval i pole `data`).
- Přejmenovat `fetchAllRosterNames` → `fetchAllRosterInfo` (jediné dnešní call site je `getRosterStatusItems.ts`, rename je bezpečný).
- Nová návratová hodnota: `Map<string, { name: string; aircraftIds: string[] }>`.
- Parsovat `JSON.parse(item.data ?? '{}')` jako `RosterData`, přebrat `aircraftIds ?? []` (deduplikace už není potřeba, ukládací cesta v `roster.ts:41` deduplikuje).
- Chyba parsu: fallback `aircraftIds: []` — nezabraňovat renderu kvůli jednomu pokažnému záznamu.

### 2. `src/Admin/Rostering/data.ts`
- V `listRosterNamesQuery` (ř. 125-145) přidat pole `data` k fieldům `id`, `name`, `rosterType`, `removed`.

### 3. `src/Admin/Scheduling/screen/Calendar/LegTimeline/useTimeline/getRosterStatusItems.ts`
- Přejmenovat modulový cache promise `rosterNameMapPromise` → `rosterInfoMapPromise` s novým typem `Promise<Map<string, { name: string; aircraftIds: string[] }>>`.
- `getRosterNameMap()` → `getRosterInfoMap()` (zachovat stejnou catch-and-reset semantiku).
- `invalidateRosterNameCache` — přejmenovat na `invalidateRosterInfoCache` (nikdo externě nevolá).
- V `getRosterStatusItems`:
  - `const rosterInfoMap = await getRosterInfoMap().catch(() => new Map());`
  - Spočítat `const rosterAircraftIds = new Set<string>(); for (const info of rosterInfoMap.values()) info.aircraftIds.forEach((id) => rosterAircraftIds.add(id));`
  - V aircraft smyčce (ř. 293) přidat hned za získání `aircraftId`:
    ```ts
    if (!rosterAircraftIds.has(aircraftId)) {
        continue; // letadlo mimo roster — nic nekreslit
    }
    ```
  - Label standalone standby pro pilota bere `name`: `rosterNameMap.get(roster.rosterID)` → `rosterInfoMap.get(roster.rosterID)?.name`.

Žádné změny v `types.ts`, `styles.sass` ani `useTimelineData.tsx` — pipeline a CSS jsou beze změn.

## Edge cases a fallback chování

- **Fetch `listRosters` selže** → cache je prázdná mapa; `rosterAircraftIds` prázdný → u **žádného** letadla se nezobrazí crew overlay ani „NO SCHEDULED CREW". Piloti (ROFF/OFF/STANDBY) zůstávají funkční. Konzistentní s dnešním principem „enrichment nemá blokovat render".
- **Letadlo je v rosteru, ale na konkrétní den nemá crew** → zachované chování, `NO SCHEDULED CREW` se vykreslí.
- **Letadlo v rosteru i v ne-rosteru souběžně** (prakticky nesmí nastat) → `rosterAircraftIds.has` vrátí true → chová se jako dnes.

## Kritické soubory

- `src/Admin/Rostering/data.ts` — GraphQL selector `listRosterNamesQuery`
- `src/Admin/Rostering/rosteringQueryUtils.ts` — `fetchAllRosterNames` → `fetchAllRosterInfo`
- `src/Admin/Scheduling/screen/Calendar/LegTimeline/useTimeline/getRosterStatusItems.ts` — cache + filtrace v aircraft smyčce

## Verifikace

1. `pnpm tsc --noEmit` (nebo skript z `package.json`) — žádné TS chyby po renamu a změně signatury.
2. Spustit dev server, otevřít `/ops/` scheduling kalendář.
3. Zkontrolovat vizuálně tři scénáře:
   - **Letadlo v `crewRoster` s přiřazenou crew na daný den** (např. běžný PC-12 CAT) → překryv „PIC: X / FO: Y".
   - **Letadlo v `crewRoster` BEZ crew na daný den** → červený text „NO SCHEDULED CREW".
   - **Letadlo MIMO `crewRoster`** (např. ATO Cirrus / školní letadlo, jehož registrace není v žádném `roster.data.aircraftIds`) → řádek bez jakéhokoli popisku/overlay.
4. Pilotské řádky: ROFF/OFF/STANDBY musí dál fungovat beze změny (včetně standalone standby s názvem rosteru).
5. Přepnout filtr Focus/Custom → roster info se re-fetchne (cache přetrvává mezi přepnutími, což je žádoucí).
