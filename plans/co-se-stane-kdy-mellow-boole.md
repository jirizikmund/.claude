# Co se stane, když spustí přepravu pod review účtem

## Context

Review účet `mtms-review@d4works.cz` má v aplikaci od minula klikatelný transport list
(`pressDisabled` odstraněn) a mock detail Plzeň → Popovice → Hradec z
`createReviewStageSetComplete()`. Otázka: **co konkrétně se stane, když Apple/Google
recenzent klikne na "Spustit přepravu" a začne procházet aktivitami?** Cílem je
identifikovat, kde flow narazí na backend, který review účet nezná, a co je
nutné dodělat, aby kompletní user-flow (start → příjezd → nakládka → drive →
navigace → vykládka → odjezd → konec) proběhl bez chyb.

## Chronologický průchod

### 1. Spuštění (klik "Start transport")

`ScreenTransportDetail/index.tsx:201-216` → `STORE.execution.startTransport({...})`
→ `src/store/execution.ts:550`.

Tok vstoupí do **demo větve** (`execution.ts:567-578`), protože jsme rozšířili
`getDemoTransportComplete()` (`transport.ts:318-332`) i o review účet:

- `TRANSPORT_STORE.downloadTransportComplete({ stageSetId })` → uloží mock do store
- `useState.getState().startTransport(startTransportParams)` (`execution.ts:101`) →
  `executingTransport = { transport, stage, activity }` s první aktivitou (Plzeň Příjezd)
- **`return true`** — žádné API se nevolá

**⚠️ Problém A:** Demo větev **NEnastavuje** `startedLocallyForTesting = true`
(to je jen v non-demo větvi na řádku 658-664). Důsledky viz krok 4.

### 2. Postup mezi aktivitami (Příjezd → Nakládka → Odjezd → …)

Každá activity komponenta (`src/components/mtms/activities/*Activity.tsx`) na
"Confirm" volá `STORE.execution.finishActivity(execution)`
(`execution.ts:148-251`). Funkce:

- ✅ Zapíše `state.finishedActivities[activityId]`
- ✅ Spočte další krok přes `TRANSPORT_STORE.getNextActivityParams()` — funguje,
  protože mock má kompletní `stages` mapping a `activitiesComplete`
- ✅ Posune `executingTransport.activity` (a případně `.stage`) na další

**⚠️ Problém B — DataSyncService:** `DataSyncService.ts:49-56` má zustand
subscribe na `finishedActivityIdsToUpload`. Jakmile se v store objeví nová
hotová aktivita, `uploadActivities()` (`DataSyncService.ts:78-97`) zavolá:

```
XLOG_TRANSPORTATION_API.Execution.SaveExecution({...})
```

Backend dostane mock systemId (`PLZEN-act0:1:6d0e5be0-...:ArrivalActivity`) a
vrátí 4xx. Aktivita se neoznačí jako uploaded, takže to navíc **periodicky
retry-uje každých 60 s** (`DataSyncService.ts:59-61`).

### 3. Drive activity → navigace

`DriveActivity` otevře `stage-navigation.tsx` → `NavigationToDestination` →
`NavigationView` → `HereMapsVisualNavigator`.

- **HereMaps init** (`utils/hereMaps.ts:37-79`): zkusí SECURE_STORE, jinak
  `XLOG_MDDATA_API.configuration.getHereMapApiKey()`. Pro review účet
  s validním přihlášením na backend by toto mělo projít (review je
  autentizovaný uživatel, jen omezený). ✅
- Souřadnice v mocku jsou reálné (Plzeň 49.7475/13.3892, Popovice 49.86/15.32,
  Hradec 50.21/15.82) → HereMaps si vypočítá trasu
- Live Activity (iOS) se aktualizuje přes `useTransportLiveActivity`
  (`hooks/useTransport.ts`) — beží na lokálních datech, žádné API ✅
- Foreground service (Android) běží z HERE Maps SDK ✅

**Pozor:** `routesAndDestinations` se počítá z `useStageSetMapRoute`
(`useTransport.ts:412`) — pokud HereMaps init selže, navigace ani Live Activity
se nezobrazí korektně. Pro recenzenta je to klíčová demonstrace persistent
location, takže HereMaps init musí být v review prostředí zaručeně funkční.

### 4. Dokončení poslední aktivity (Hradec → Odjezd)

`finishActivity` určí `nextActivityParams.status === 'transportFinished'`
(`execution.ts:222-229`) → nastaví `isFinishing = true` a `stageSetIdToFinish`.

Pak `execution.ts:242-250`:

```ts
if (get().executingTransport?.startedLocallyForTesting) {
  state.executingTransport = undefined;
} else {
  finishTransportOnServer(stageSetIdToFinish);  // ❌ API call
}
```

**Protože jsme v kroku 1 nenastavili `startedLocallyForTesting`,** spadne to do
`else` větve a zavolá se `finishTransportOnServer` (`execution.ts:668`) →
`XLOG_TRANSPORTATION_API.StageSet.StageSetEnd({ body: stageSetId })` →
backend mock stageSetId nezná → **Alert "Chyba při ukončování přepravy"
s Retry tlačítkem** (`execution.ts:688-698`).

## Co tedy review účet uvidí dnes

| Krok | Stav |
|---|---|
| Start přepravy | ✅ funguje (lokálně) |
| Příjezd Plzeň, Nakládka, Odjezd | ✅ funguje, ale… |
| …každá hotová aktivita | ⚠️ pošle `SaveExecution` API → backend 4xx, retry každých 60 s |
| Drive activity + navigace HERE Maps | ✅ funguje (pokud HERE Maps API klíč přijde z backendu) |
| Live Activity / foreground notification | ✅ funguje |
| Dokončení celé přepravy | ❌ Alert s chybou `StageSetEnd`, přeprava zůstane visel v `isFinishing` |

V praxi by Apple recenzent **prošel klíčovou demonstraci background location**
(start → drive → navigace + Live Activity), ale **na konci by viděl error
alert**, což může být důvod dalšího odmítnutí.

## Doporučené opravy (2 minimální patches)

### Patch 1 — `src/store/execution.ts:567-578`

V demo větvi nastavit `startedLocallyForTesting = true` ihned po
`startTransport(params)`, aby `finishTransportOnServer` nikdy nevolal
`StageSetEnd` API pro demo/review účet:

```ts
const demoTransport = getDemoTransportComplete({ stageSetId });
if (isSome(demoTransport)) {
  const startTransportParams = getStartTransportParams(demoTransport);
  if (isSome(startTransportParams)) {
    await TRANSPORT_STORE.downloadTransportComplete({ stageSetId });
    useState.getState().startTransport(startTransportParams);
    useState.setState((state) => {
      if (state.executingTransport) {
        state.executingTransport.startedLocallyForTesting = true;
      }
    });
    return true;
  }
  // …
}
```

Použije se existující flag, žádný nový mechanismus. Mimochodem tohle dnes
opravuje i **demo účet**, který má stejnou neviditelnou chybu (`StageSetEnd`
se volá s fake stageSetId).

### Patch 2 — `src/services/DataSyncService.ts:78-97`

Před `for` smyčkou přidat guard pro demo/review účet — žádný `SaveExecution`
nikdy nepošle a aktivita zůstane v lokálním store:

```ts
private async uploadActivities(activitiesToUpload: FinishedActivity[]) {
  if (this.syncing || isEmpty(activitiesToUpload)) return;
  if (STORE.app.getIsDemoAccount() || STORE.app.getIsReviewAccount()) return;
  this.syncing = true;
  // …
}
```

Tím zastavíme i 60s retry loop pro mock přepravy.

## Kritické soubory

- `src/store/execution.ts:550-666` — `startTransport` (demo větev na 567)
- `src/store/execution.ts:148-251` — `finishActivity` (volá `finishTransportOnServer` na 249)
- `src/store/execution.ts:668-700` — `finishTransportOnServer`
- `src/services/DataSyncService.ts:78-97` — `uploadActivities`
- `src/store/transport.ts:318-332` — `getDemoTransportComplete` (už pokrývá review)
- `src/api/mock/ReviewStageSet_complete.ts` — mock detail
- `src/utils/hereMaps.ts:37-79` — HereMaps init (závisí na backendu)

## Reuse existujících utilit

- `startedLocallyForTesting` flag (`execution.ts:54`) — již existuje, jen ho v demo
  větvi nezapínáme; patch 1 to napraví
- `APP_STORE.getIsReviewAccount()` / `getIsDemoAccount()` (`store/app.ts:140-142`,
  `store/app.ts:197-206`) — selektor je hotový
- `STORE.app.getIsDemoAccount()` se používá v `getDemoTransportComplete` —
  identický pattern aplikujeme v `DataSyncService`

## Verifikace

1. **Type-check**: `npx tsc --noEmit` (po obou patchech musí být 0 errors).
2. **Lint**: `npx eslint src/store/execution.ts src/services/DataSyncService.ts`.
3. **Manuální flow** v simulátoru s loginem `mtms-review@d4works.cz`:
   - Klik na první "allowed" transport → otevře se detail s 3 lokacemi
   - Klik "Spustit přepravu" → status přepne na `executing`, žádný alert
   - Otevřít Sentry/console — žádný `SaveExecution` request
   - Postupně proklikat Příjezd → Nakládka → Odjezd (Plzeň) → Drive → spustit
     navigaci v HereMaps Visual Navigator → zamknout obrazovku → ověřit Live
     Activity / Android notification "Navigation Live Updates"
   - Vrátit se → Příjezd Popovice → Vykládka → Nakládka → Odjezd → Drive →
     Příjezd Hradec → Vykládka → Odjezd
   - Po dokončení posledního Odjezdu **nesmí přijít** žádný error alert; v
     transport listu se přeprava přepne na `finished`
4. **Sentry breadcrumbs**: ověřit, že po dokončení review-přepravy chybí volání
   `Execution_SaveExecution` a `StageSet_StageSetEnd`.
5. **DataSyncService timer**: po `manualSync` (DevConsole) i po čekání 60 s
   nesmí přijít sítěový request s mock execution payloadem.

## Otevřené body

- Patch 1 zároveň mění chování pro **demo účet** — `StageSetEnd` přestane být
  volán i pro demo. To je defakto bug-fix, ale stojí za to v PR description
  zmínit, aby se to potkalo s expectaci ostatních.
- Patch 2 v `DataSyncService` použije `STORE.app.getIsReviewAccount()` —
  ověřit, že tento static accessor existuje (vidím `getIsReviewAccount` na
  `store/app.ts:197`).
