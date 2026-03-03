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

## Jediné řešení
**Upgrade React Native na 0.76+** — dodává .so s 16KB alignmentem.

### Odhad upgradu RN 0.74 → 0.76+
- **Střední složitost** (~týden práce)
- 47 nativních závislostí (Firebase 21.6.1, Reanimated 3.15.5, Notifee 9.1.8, Klarna SDK…)
- 7 patchů (961 řádků) — hlavně react-native-render-html (631 řádků)
- Custom nativní kód: Klarna SDK bridge (Android Java + iOS Swift)
- minSdkVersion 23 → pravděpodobně bude potřeba 24+
- Flavors: zoot, bibloo

### Kroky upgradu
1. Research kompatibility závislostí s RN 0.76
2. Bump RN a @react-native/* balíčků
3. Přeaplikovat/přepsat patche
4. Aktualizovat Android build config (AGP, Gradle budou nové s RN 0.76)
5. Aktualizovat iOS config (Podfile, deployment target)
6. Otestovat Klarna bridge
7. Otestovat notifikace (Notifee + Firebase)
8. Full QA na obou platformách

## Otevřené otázky
- Má se revertovat quick-fix commit (aeae7221)? Změny (compileSdk 35, AGP 8.5.2) neuškodí, ale neřeší 16KB.
- Google Play deadline pro 16KB enforcement — ověřit aktuální stav
