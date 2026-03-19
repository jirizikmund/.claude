# TMS-428: Logování chyb při spuštění přepravy do Sentry

## Kontext
Funkce `startTransport()` v `src/store/execution.ts` má několik chybových větví, které zobrazují alert uživateli, ale nelogují se do Sentry. Existuje TODO komentář na řádku 599. `SentryService` existuje jako stub (`src/utils/sentry/index.ts`) — přidáme volání, která se automaticky aktivují až se SDK nastaví.

## Plán

### 1. Přidat `SentryService` volání do všech chybových větví `startTransport()`

Soubor: `src/store/execution.ts`

Každý error path dostane `SentryService.captureException()` s kontextem (`stageSetId`, `externalEntityId`):

- ř. 552-554: API fetch selhání → log
- ř. 556-558: stageSetStatus === 0 (transport not ready) → log
- ř. 572-574: StageSetStart API selhání → log
- ř. 576-578: transport already finished → log
- ř. 580-582: transport deleted → log
- ř. 588-591: fetchTransportComplete selhání → log
- ř. 597-605: missing params → log s `errorId` (nahradit TODO)

Nelogovat:
- ř. 527-529: jiná přeprava běží — to je normální stav, ne chyba
- ř. 531-533: chybí externalEntityId — toto by mohla být chyba, ale je to validace parametrů

### 2. Přidat import `SentryService`

Do `src/store/execution.ts` přidat import z `@/utils/sentry`.

## Soubory k úpravě
- `src/store/execution.ts` — přidat Sentry logging do error paths

## Ověření
- `npx tsc --noEmit` — žádné type errory
