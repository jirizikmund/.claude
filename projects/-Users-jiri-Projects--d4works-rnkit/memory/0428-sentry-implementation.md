# Implementace Sentry v rnkitu

**Stav: DONE** (commity: `d34991e`, `004125a`)

## Rozhodnutí

- **DSN**: Jediná hodnota v `rnkit.config.json` (sekce `sentry.dsn`)
- **Environment**: Za běhu z `APP_ENV` (`'test' | 'production'`) — synchronně dostupný přes `STATIC_ENV.APP_ENV`
- **Inicializace**: `SentryService.init()` bez parametrů — DSN z generovaného souboru, environment z `APP_ENV`
- **Sentry.wrap()**: Automaticky v `RnkitAppProvider` (podmíněně, pokud je Sentry inicializované)
- **XHR breadcrumbs**: Middleware v API šabloně
- **Package manager**: yarn (ne pnpm)

## Plán implementace

### 1. Nainstalovat `@sentry/react-native`

```bash
yarn add @sentry/react-native
```

### 2. Přidat `sentry` sekci do `RnkitConfig` a build-time skript

Soubor: `src/scripts/rnkitConfig.ts`
- Rozšířit `RnkitConfig` typ o `sentry?: { dsn?: string }`

Nový soubor (generovaný): sentry config — build-time skript vygeneruje statický soubor s DSN hodnotou (stejný pattern jako fonty/barvy/konstanty).

### 3. Rozšířit `SentryService`

Soubor: `src/utils/sentry/index.ts`

- `isInitialized` statický flag
- `SentryService.init()` — bez parametrů, vezme DSN z generovaného souboru, environment z `APP_ENV`
- `SentryService.captureException(err, options?)` — volá `Sentry.captureException()`
- `SentryService.captureMessage(msg, options?)` — volá `Sentry.captureMessage()`, podporuje `sendNotification` tag
- `SentryService.addBreadcrumb(breadcrumb)` — propojit s `Sentry.addBreadcrumb()`
- `SentryService.addXHRRequestBreadcrumb(context)` — HTTP breadcrumb z response kontextu
- Exportovat typy: `Extra`, `Extras`, `SeverityLevel`, `CaptureMessageOptions`
- Všechny metody jsou no-op pokud `isInitialized === false`

### 4. Upravit `initRnkit()` a `useRnkitInit()`

Soubor: `src/app/init.ts`

- V `initRnkit()` synchronně zavolat `SentryService.init()` **před** `Promise.all`
- V catch bloku `useRnkitInit` volat `SentryService.captureException()`

### 5. Integrovat Sentry.wrap() do `RnkitAppProvider`

Soubor: `src/app/RnkitAppProvider.tsx`

- Podmíněně obalit obsah `Sentry.TouchEventBoundary` pokud `SentryService.isInitialized`

### 6. Exportovat Sentry typy a service z rnkitu

Soubory:
- `src/utils/index.ts` — ověřit `export * from './sentry'`
- `src/index.tsx` — typy se propagují přes utils barrel

### 7. Aktualizovat `__IMPLEMENT_HELPERS__.ts` šablonu

Soubor: `lib_source/api/__IMPLEMENT_HELPERS__.ts`

- Importovat `SentryService` a `CaptureMessageOptions` z rnkitu
- Implementovat `captureSentryMessage`
- Smazat lokální definice typů (`Extra`, `Extras`, `CaptureMessageOptions`)

### 8. Aktualizovat `__IMPLEMENT_API__.ts` šablonu

Soubor: `lib_source/api/__IMPLEMENT_API__.ts`

- Importovat `SentryService` z rnkitu
- Implementovat `xhrSentryLogMiddleware`

## Klíčové soubory

- `APP_ENV`: `src/utils/env/appEnv.ts` — typ `'test' | 'production'`, synchronní
- `STATIC_ENV.APP_ENV`: `src/utils/env/index.ts` — dostupný bez `initEnvAsync()`
- Config loading: `src/scripts/rnkitConfig.ts`
- Existující config: `rnkit.config.json`

## Verifikace

1. `yarn build` (nebo `pnpm build`) — TypeScript kompilace
2. Exporty obsahují `SentryService`, `CaptureMessageOptions`, `Extra`, `Extras`, `SeverityLevel`
3. `SentryService` metody jsou no-op bez init
