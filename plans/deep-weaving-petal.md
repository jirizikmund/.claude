# TMS-330: QR Code Scanning pro LoadUnloadActivity

## Krok 0: Uložení plánu a nastavení
- Uložit tento plán jako `docs/plans/TMS-330.md` v repozitáři
- Přidat do `CLAUDE.md` sekci `## Aktivní plány` s odkazem na `docs/plans/`
- Aktualizovat MEMORY.md s odkazem na in-repo plán
- Commitnout jako `[TMS-330] Add implementation plan for QR scanning`

## Context
LoadActivity/UnloadActivity potřebuje QR skenování pro validaci rampy, racku a palet (SSCC). Backend posílá boolean flagy `RampScan`, `RackScan`, `PalletScan` v datech aktivity. Pokud je flag true, uživatel musí naskenovat příslušný QR/barcode před pokračováním. Ramp a rack se validují offline proti hodnotám z aktivity, SSCC se validuje přes API.

## Flow subaktivit v LoadUnloadActivity
```
1. SkipConfirmTime          (conditional - Skippable)
2. StartLoadingConfirmTime  (vždy)
3. RampScanConfirmTime      (conditional - RampScan === true)  ← NOVÉ
4. RackScanConfirmTime      (conditional - RackScan === true)  ← NOVÉ
5. PalletScanConfirmTime    (conditional - PalletScan === true) ← NOVÉ
6. DplCountConfirmTime      (vždy)
7. PhotosConfirmTime        (conditional - PhotoRequired)
8. DepartureConfirmTime     (vždy)
```

## Změny v souborech

### 1. Activity Type & Parser
**`src/utils/parsers/activity/parseActivity.ts`**
- Přidat `Rack?: string` do Activity type (zatím jen v unparsedData)
- Přidat `RampScan?: boolean` do Activity type
- Přidat oba do `ACTIVITY_PARSER_CONFIG`

### 2. Execution Types
**`src/utils/parsers/execution/types.ts`**
- Přidat do `LoadExecution` interface:
  ```
  RampScanConfirmTime?: Date
  RampScanValue?: string
  RackScanConfirmTime?: Date
  RackScanValue?: string
  PalletScanConfirmTime?: Date
  PalletScanValue?: string
  ```
- `UnloadExecution` dědí z `LoadExecutionData`, takže se změní automaticky

### 3. SSCC Validation API
**`src/api/xlog-transportation/__IMPLEMENT_API__.ts`**
- Přidat do `Activity` sekce:
  ```typescript
  validateSSCCForShipment: this.createApiCall(
    'activityApi',
    'activityValidateSSCCForShipmentPostRaw',
    'Activity_validateSSCCForShipment',
  ),
  ```

**`src/api/index.ts`**
- Přidat hook `useApi_Activity_ValidateSSCCForShipment()`

### 4. Nové subaktivity komponenty

**`src/components/mtms/activities/LoadUnloadActivity/RampScanSubactivity.tsx`**
- Otevře kameru přes `CameraCodeScannerView` (codeTypes: `['qr']`)
- Skenuje QR, porovná celou hodnotu s `activity.Ramp`
- Match → setData `RampScanConfirmTime` + `RampScanValue`
- Mismatch → červená hláška "Stojíte na špatné rampě, měl byste být na {{ramp}}. Volejte dispečink."
- Kamera zůstane otevřená dokud není správný kód
- Pokud `activity.Ramp` je null/undefined ale `RampScan` je true → zobrazit chybu (nelze validovat)

**`src/components/mtms/activities/LoadUnloadActivity/RackScanSubactivity.tsx`**
- Stejný pattern jako RampScan
- Validuje proti `activity.Rack`
- Chybová hláška "Špatný rack, očekáván {{rack}}. Volejte dispečink."
- Pokud `activity.Rack` je null → zobrazit chybu

**`src/components/mtms/activities/LoadUnloadActivity/PalletScanSubactivity.tsx`**
- Otevře kameru s `codeTypes: ['code-128', 'ean-13', 'qr']` (barcode pro SSCC)
- SSCC formát: přesně 18 číslic (`^[0-9]{18}$`)
- Po naskenování zavolá API: `validateSSCCForShipment({ sscc: scannedValue, shipmentId: activity.ExternalId })`
- API vrátí `boolean`:
  - `true` → setData `PalletScanConfirmTime` + `PalletScanValue`
  - `false` → chybová hláška "Neplatný SSCC kód, naskenujte prosím správnou paletu."
- Loading state během API volání

### 5. Úprava LoadUnloadActivity
**`src/components/mtms/activities/LoadUnloadActivity/index.tsx`**
- Rozšířit `parserConfig` o nové fields (6 nových: 3x ConfirmTime + 3x Value)
- Rozšířit `SUBACTIVITY_KEYS` o `RampScanConfirmTime`, `RackScanConfirmTime`, `PalletScanConfirmTime`
- Předat `activity` prop do `SubactivityProps` (potřeba pro přístup k `Ramp`, `Rack`, `ExternalId`, scan flagům)
- V `KEYS_FOR_STATUSES` - přeskočit scan klíče pokud příslušný flag není true
- V `SUBACTIVITY_KEYS_TO_RENDER` - přeskočit scan klíče pokud příslušný flag není true
- V `Subactivity` switch - přidat case pro nové klíče
- V `DebugDataView` reset - přidat nové fields

### 6. CameraCodeScannerView úprava
**`src/components/ui/CameraCodeScannerView.tsx`**
- Prop `stageSetId` udělat optional (není potřeba pro scan subaktivity)
- Dev mode placeholder: přidat tlačítko pro simulaci scanu s konfigurovatelnou hodnotou

### 7. Překlady (i18n)
**`src/i18n/locales/cs.json`** (+ en, de, sk, uk)
- Přidat pod `activity.LoadActivity`:
  ```json
  "rampScan": {
    "_title": "Skenování rampy",
    "_titleDone": "Rampa ověřena",
    "description{{ramp}}": "Naskenujte QR kód na rampě {{ramp}}.",
    "wrongRamp{{ramp}}": "Stojíte na špatné rampě, měl byste být na {{ramp}}. Volejte dispečink.",
    "missingValue": "Chyba: Hodnota rampy není k dispozici pro validaci."
  },
  "rackScan": {
    "_title": "Skenování racku",
    "_titleDone": "Rack ověřen",
    "description{{rack}}": "Naskenujte QR kód na racku {{rack}}.",
    "wrongRack{{rack}}": "Špatný rack, očekáván {{rack}}. Volejte dispečink.",
    "missingValue": "Chyba: Hodnota racku není k dispozici pro validaci."
  },
  "palletScan": {
    "_title": "Skenování palety (SSCC)",
    "_titleDone": "Paleta ověřena",
    "description": "Naskenujte SSCC kód na paletě.",
    "validating": "Ověřuji SSCC...",
    "invalid": "Neplatný SSCC kód, naskenujte prosím správnou paletu.",
    "error": "Chyba při ověřování SSCC, zkuste to znovu."
  }
  ```
- Stejné klíče pod `activity.UnloadActivity`
- Přeložit do en, de, sk, uk

### 8. Mock data
**`src/utils/parsers/activity/MOCK_DATA.ts`** a **`src/api/mock/demo/`**
- Aktualizovat mock data aby obsahovala `RampScan`, `Rack`, nové fields

## Klíčové soubory k modifikaci
1. `src/utils/parsers/activity/parseActivity.ts` - Activity type + parser
2. `src/utils/parsers/execution/types.ts` - Execution types
3. `src/components/mtms/activities/LoadUnloadActivity/index.tsx` - Hlavní orchestrace
4. `src/components/ui/CameraCodeScannerView.tsx` - Úprava pro generické použití
5. `src/api/xlog-transportation/__IMPLEMENT_API__.ts` - SSCC API endpoint
6. `src/api/index.ts` - SSCC API hook
7. `src/i18n/locales/*.json` - Překlady (6 souborů)
8. Nové soubory: `RampScanSubactivity.tsx`, `RackScanSubactivity.tsx`, `PalletScanSubactivity.tsx`

## Existující kód k reuse
- `CameraCodeScannerView` (`src/components/ui/CameraCodeScannerView.tsx`) - camera + QR scanning
- `SubactivityPanel` (`src/components/mtms/SubActivityPanel.tsx`) - subactivity UI wrapper
- `useSubactivityData` (`src/components/mtms/activities/utils/useSubactivityData.ts`) - state management
- `useApi` (`src/api/index.ts`) - API call hook pattern
- `createApiCall` pattern z `__IMPLEMENT_API__.ts`

## Verifikace
1. Build: `npx expo prebuild` + `npx expo run:ios`
2. Test s mock daty: upravit MOCK_DATA aby `RampScan=true`, `RackScan=true`, `PalletScan=true`
3. Ověřit flow: Skip → Start → RampScan → RackScan → PalletScan → DplCount → Photos → Departure
4. Ověřit error states: špatný QR, null Rack/Ramp, API error pro SSCC
5. Ověřit že scan subaktivity se nezobrazí když flagy jsou false
6. TypeScript: `npx tsc --noEmit`
