# TMS-330: QR Code Scanning pro LoadUnloadActivity

## Stav: PLÁN SCHVÁLEN - čeká na implementaci

## Shrnutí
Přidat QR/barcode skenování do LoadUnloadActivity pro validaci rampy, racku a palet (SSCC).

## Klíčová rozhodnutí
- Scan flagy: `RampScan`, `RackScan`, `PalletScan` (boolean) řídí zobrazení
- Oddělené subaktivity pro každý typ scanu
- Pořadí: Skip → StartLoading → RampScan → RackScan → PalletScan → DplCount → Photos → Departure
- QR text = celá hodnota, porovnává se přímo s activity.Ramp / activity.Rack
- SSCC je barcode (Code128/EAN), formát 18 číslic, validace přes API
- SSCC API: `POST /Activity/validateSSCCForShipment` s `{ sscc, shipmentId }`
- Execution data: posílat ConfirmTime + naskenovanou Value
- Null Rack/Ramp s aktivním scanem → zobrazit chybu uživateli

## Soubory k modifikaci
1. `src/utils/parsers/activity/parseActivity.ts` - přidat Rack, RampScan
2. `src/utils/parsers/execution/types.ts` - přidat scan fields do LoadExecution
3. `src/components/mtms/activities/LoadUnloadActivity/index.tsx` - orchestrace
4. `src/components/ui/CameraCodeScannerView.tsx` - optional stageSetId
5. `src/api/xlog-transportation/__IMPLEMENT_API__.ts` - SSCC API endpoint
6. `src/api/index.ts` - SSCC API hook
7. `src/i18n/locales/*.json` - překlady

## Nové soubory
- `src/components/mtms/activities/LoadUnloadActivity/RampScanSubactivity.tsx`
- `src/components/mtms/activities/LoadUnloadActivity/RackScanSubactivity.tsx`
- `src/components/mtms/activities/LoadUnloadActivity/PalletScanSubactivity.tsx`

## Kompletní plán
Viz `/Users/jiri/.claude/plans/deep-weaving-petal.md`
