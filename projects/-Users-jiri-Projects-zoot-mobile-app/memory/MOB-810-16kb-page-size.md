# MOB-810: 16KB page size support pro Android

## Problém
Google Play odmítá release — app nepodporuje 16KB stránkování paměti.

## Co bylo uděláno (commity na masteru)
1. `894556ad` — NDK 27.1 + `useLegacyPackaging = true` (původní pokus)
2. `0e5093ba` — Upgrade react-native-reanimated na 3.15.5
3. `aeae7221` — Quick-fix: AGP 8.5.2, Gradle 8.7, compileSdk 35, odstranění useLegacyPackaging
4. `450c4558` — Version bump v21.15.4 (600)

## Quick-fix nestačí
Ověřeno na release AAB (`llvm-readelf -lW`):
- **0x4000 (16KB)** — libc++_shared, libcrashlytics*, libsentry* — OK
- **0x1000 (4KB)** — **všechny RN core .so** (Hermes, Yoga, Reanimated, Fabric, JSI, …)

Pre-built `.so` z React Native 0.74 mají 4KB ELF segment alignment. Konfigurační změny (AGP, Gradle, compileSdk) toto neřeší — binárky jsou součástí RN balíčku.

## Řešení: Upgrade RN 0.74.5 → 0.77.3
Minimální verze s 16KB podporou je **RN 0.77.0** (leden 2025).
RN 0.75 ani 0.76 problém neřeší — pre-built .so zůstávají 4KB-aligned.

### Plán upgrade (po krocích, s jednotlivými commity)

#### Krok 1: package.json — JS závislosti ⬜
- `react`: 18.2.0 → 18.3.1
- `react-native`: 0.74.5 → 0.77.3
- `react-test-renderer`: 18.2.0 → 18.3.1
- `@react-native/babel-preset`: 0.74.87 → 0.77.3
- `@react-native/eslint-config`: 0.74.87 → 0.77.3
- `@react-native/metro-config`: 0.74.87 → 0.77.3
- Přidat `@react-native-community/cli`: 15.0.1
- Přidat `@react-native-community/cli-platform-android`: 15.0.1
- Přidat `@react-native-community/cli-platform-ios`: 15.0.1
- metro.config.js: minor type annotation fix

#### Krok 2: Android build config ⬜
- `buildToolsVersion`: 34 → 35
- `minSdkVersion`: 23 → 24
- `kotlinVersion`: 1.9.22 → 2.0.21
- Gradle: 8.7 → 8.10.2
- `android/settings.gradle`: nový autolinking (pluginManagement)
- `android/app/build.gradle`: `autolinkLibrariesWithApp()`, odstranit starý native_modules.gradle
- `gradle.properties`: odstranit jetifier, newArchEnabled=false (ponechat)
- `MainApplication.kt`: aktualizovat SoLoader.init()
- AndroidManifest.xml: přidat `android:supportsRtl="true"`

#### Krok 3: iOS config ⬜
- Ponechat ObjC AppDelegate (nemigrovat na Swift)
- Případná úprava deployment targetu
- Odstranit Tests target z Podfile
- `pod install`

#### Krok 4: Kontrola patchů ⬜
7 patchů — ověřit že se aplikují na nové verze

#### Krok 5: yarn install + build + fix ⬜

### Rozhodnutí
- **New Architecture**: newArchEnabled=false (bezpečnější pro hotfix)
- **AppDelegate**: ponechat ObjC, nemigrovat na Swift
- **Cíl**: minimální změny pro 16KB podporu
