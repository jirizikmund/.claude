# Quick-fix: 16KB page size support pro Android

## Context
Google Play odmítá release, protože app nepodporuje 16KB stránkování paměti. Aktuální AGP 8.2.1 (z RN gradle pluginu) neumí automaticky zarovnat `.so` soubory na 16KB. Cílem je opravit tohle bez upgradu React Native.

## Změny

### 1. Upgrade Gradle wrapper 8.6 → 8.7
- **Soubor:** `android/gradle/wrapper/gradle-wrapper.properties`
- Změnit `distributionUrl` na `gradle-8.7-all.zip`
- Důvod: AGP 8.5.x vyžaduje Gradle 8.7+

### 2. Pin AGP na 8.5.2
- **Soubor:** `android/build.gradle`
- Změnit `classpath("com.android.tools.build:gradle")` → `classpath("com.android.tools.build:gradle:8.5.2")`
- Přepíše výchozí AGP 8.2.1 z RN gradle pluginu

### 3. Bump compileSdkVersion 34 → 35
- **Soubor:** `android/build.gradle`
- Změnit `compileSdkVersion = 34` → `compileSdkVersion = 35`

### 4. Odstranit useLegacyPackaging
- **Soubor:** `android/app/build.gradle`
- Smazat blok `packaging { jniLibs { useLegacyPackaging = true } }`
- S AGP 8.5+ a výchozím `useLegacyPackaging = false` se `.so` soubory automaticky zarovnají na 16KB v AAB

## Ověření
1. `cd android && ./gradlew assembleRelease` — ověřit že build projde
2. Zkontrolovat alignment `.so` souborů v release AAB/APK
3. Upload na Google Play a ověřit že chyba zmizela
