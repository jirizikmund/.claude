# TMS-496: Opravit Android release - neznámý jazyk "zz"

## Kontext

Google Play odmítá App Bundle s chybou: *"The bundle targets unrecognized languages: zz"*. Pseudo-locale "zz" se dostává do bundlu přes AAR závislost (HERE SDK nebo jiná nativní knihovna).

### Historie problému
1. **TMS-310** — vytvořen `plugins/withAppBuildGradlePlugin.js` (přidával `resConfigs` do `defaultConfig`) → **fungoval**
2. **TMS-345** (říjen 2025) — plugin odstraněn jako "zbytečný hotfix" → chyba se vrátila
3. **TMS-429** (únor 2026) — pokus o opravu přes `resourceConfigurations` v `expo-build-properties` → **nefunguje** (tato property v pluginu neexistuje, je silentně ignorována)

### Příčina
`expo-build-properties` nemá property `resourceConfigurations` ve svém schématu ani v Gradle výstupu. Konfigurace v `app.json` je mrtvý kód. Původní funkční plugin byl omylem odstraněn.

## Řešení

Obnovit custom config plugin (v čistší verzi s `mergeContents` pro idempotenci). Odstranit nefunkční `resourceConfigurations`.

## Kroky

### 1. Vytvořit `plugins/withResConfigs.js`
Config plugin přes `withAppBuildGradle` + `mergeContents` (z `@expo/config-plugins`) vloží `resConfigs "cs", "de", "en", "sk", "uk"` do `defaultConfig` bloku. Vzor: `node_modules/expo-here-maps/plugin/src/withHereMapsSdk.ts`.

### 2. Upravit `app.json`
- Přidat plugin: `["./plugins/withResConfigs", ["cs", "de", "en", "sk", "uk"]]`
- Odstranit nefunkční `resourceConfigurations` z `expo-build-properties` (celý plugin smazat, pokud nemá jiné properties)

### 3. Ověření
- `npx expo prebuild --platform android --clean` → zkontrolovat `resConfigs` v `android/app/build.gradle`
- Smazat vygenerovaný `android/` adresář

## Soubory
- **Nový:** `plugins/withResConfigs.js`
- **Úprava:** `app.json` (řádky 56-69 — smazat expo-build-properties, přidat nový plugin)
