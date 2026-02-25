# MFTL Mobile App - Memory

## Architektura projektu
- Expo Router app s tabs layoutem (auth, transport/training)
- State management: Zustand (store/app, execution, transport, data, settings)
- API: 3 swagger-generované API klienty v `src/api/` (access, mddata, transportation)
  - Swagger JSON definice: `src/api/xlog-access.json`, `src/api/xlog-mddata.json`, `src/api/xlog-transportation.json`
  - API klienty zabalené v `XlogTransportationApi` class s `createApiCall` pattern
  - React hooky přes `useApi()` v `src/api/index.ts`
- UI knihovna: `@d4works/rnkit`
- Camera: `react-native-vision-camera` s `useCodeScanner` hook

## Aktivní úlohy
- **TMS-330**: QR skenování pro LoadUnloadActivity - viz `plans/tms330-qr-scanning.md`

## Konvence
- API definice ve swaggeru ve složce `src/api` - 3 API: access, mddata, transportation
- Subaktivity pattern: `SubactivityPanel` + `useSubactivityData` hook + `parserConfig`
- Execution creation: `createExecution()` pattern v `utils/createExecution.ts`
