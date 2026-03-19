# Implementace Sentry v rnkitu

## Context

V mFTL appce existují 2 nezávislé Sentry stuby. Rnkit má stub `SentryService` (jen prázdný `addBreadcrumb`) a zakomentovaný `captureSentryMessage` v API helpers šabloně. Cílem je plně implementovat Sentry v rnkitu, aby ho mohly využívat všechny projekty.

## Rozhodnutí

- **Inicializace**: Součást `initRnkit(options)` — Sentry se inicializuje synchronně na začátku funkce
- **Sentry.wrap()**: Automaticky v `RnkitAppProvider` (podmíněně, pokud je Sentry inicializované)
- **XHR breadcrumbs**: Implementovat hned — middleware v API šabloně

---

## Plán implementace

### 1. Nainstalovat `@sentry/react-native`

```bash
pnpm add @sentry/react-native
```

Soubor: `package.json`

### 2. Rozšířit `SentryService`

Soubor: `src/utils/sentry/index.ts`

- Přidat statický `isInitialized` flag
- `SentryService.init(options)` — volá `Sentry.init()`, nastaví flag
- `SentryService.captureException(err, options?)` — volá `Sentry.captureException()` s extra daty a severity level
- `SentryService.captureMessage(msg, options?)` — volá `Sentry.captureMessage()` s extra daty, podporuje `sendNotification` tag
- `SentryService.addBreadcrumb(breadcrumb)` — propojit s `Sentry.addBreadcrumb()`
- `SentryService.addXHRRequestBreadcrumb(context)` — vytvoří HTTP breadcrumb z response kontextu (url, status, method)
- Exportovat typy: `Extra`, `Extras`, `SeverityLevel`, `CaptureMessageOptions`, `SentryInitOptions`
- Všechny metody jsou no-op pokud `isInitialized === false` (bezpečné pro projekty bez Sentry)

### 3. Upravit `initRnkit()` a `useRnkitInit()`

Soubor: `src/app/init.ts`

- Přidat `InitRnkitOptions` typ s volitelným `sentry?: SentryInitOptions`
- V `initRnkit(options?)` synchronně zavolat `SentryService.init()` **před** `Promise.all`
- V `useRnkitInit(options?)` předat options do `initRnkit()`
- V catch bloku `useRnkitInit` volat `SentryService.captureException()`

### 4. Integrovat Sentry.wrap() do `RnkitAppProvider`

Soubor: `src/app/RnkitAppProvider.tsx`

- Podmíněně obalit obsah `Sentry.TouchEventBoundary` pokud `SentryService.isInitialized`
- Pokud Sentry není inicializované, render bez wrapperu (Fragment)

### 5. Exportovat Sentry typy a service z rnkitu

Soubory:
- `src/utils/index.ts` — přidat `export * from './sentry'`
- `src/index.tsx` — typy se propagují přes utils barrel

### 6. Aktualizovat `__IMPLEMENT_HELPERS__.ts` šablonu

Soubor: `lib_source/api/__IMPLEMENT_HELPERS__.ts`

- Importovat `SentryService` a `CaptureMessageOptions` z rnkitu (`../../src/utils/sentry` nebo relativní cesta v rámci generovaného kódu)
- Implementovat `captureSentryMessage` — volá `SentryService.captureMessage(msg, options)`
- Smazat lokální definice typů (`Extra`, `Extras`, `CaptureMessageOptions`)

### 7. Aktualizovat `__IMPLEMENT_API__.ts` šablonu

Soubor: `lib_source/api/__IMPLEMENT_API__.ts`

- Importovat `SentryService` z rnkitu
- Odkomentovat a implementovat `xhrSentryLogMiddleware` — volá `SentryService.addXHRRequestBreadcrumb(context)`

---

## Verifikace

1. Build: `pnpm build` — ověřit že TypeScript kompilace projde
2. Ověřit že exporty z rnkitu obsahují `SentryService`, `CaptureMessageOptions`, `Extra`, `Extras`, `SeverityLevel`
3. Ověřit že `SentryService` metody jsou no-op bez init (bezpečné pro projekty bez Sentry)
