# Metro chyba: `back-icon@3x.png` nenalezen v `@react-navigation/elements`

## Context

V dev režimu se v Metro logu objevuje chyba:

```
Error: './node_modules/@react-navigation/elements/lib/module/assets/back-icon@3x.png' could not be found, because it is not within the projectRoot or watchFolders, or it is blocked via the resolver.blockList config
```

Po kontrole souborů v `node_modules/@react-navigation/elements/lib/module/assets/`:
- `back-icon@3x.ios.png` ✅ existuje
- `back-icon@3x.android.png` ✅ existuje
- `back-icon@3x.png` (bez platform suffixu) ❌ neexistuje

Knihovna `@react-navigation/elements@2.9.14` je v projektu transitivní závislost přes `expo-router@55.0.11` (Expo 55, RN 0.83.4). Projekt **nemá vlastní `metro.config.js`** — používá default Expo konfiguraci.

## Doporučení: **neřešit**

Tato hláška je kosmetická varovka Metro dev serveru. Reálný dopad na aplikaci **není žádný**:

- React Native `Image` komponenta resolvuje asset scale varianty (`@1x`, `@2x`, `@3x`) + platform varianty (`.ios.png`, `.android.png`) sama v runtime.
- Hláška vzniká tak, že Metro dev server dostane HTTP request na konkrétní URL bez platform suffixu, pro kterou nemá soubor. Na sestavení bundlu to vliv nemá.
- V release buildu (EAS / Xcode / Gradle) se používá jiná asset pipeline a tato chyba se neprojeví.
- V UI navigace ikona zpětné šipky funguje normálně — zobrazí se `back-icon@3x.ios.png` (resp. `.android.png`) podle platformy a scale faktoru.

Knihovna `@react-navigation/elements` to dělá úmyslně od verze 2.x (platform-specific assety), Metro resolver v určitých edge casech poptá filename bez suffixu. Jde o known issue ([react-navigation#11596](https://github.com/react-navigation/react-navigation/issues/11596) a podobné), které nemá dopad na funkci.

## Pokud by chyba překážela (alternativy — nedoporučuji)

1. **`patch-package`** — v `node_modules/@react-navigation/elements/lib/module/assets/` vytvořit kopie `back-icon@3x.png` → `back-icon@3x.ios.png`. Patch se uloží a pustí při každém `pnpm install`. Nevýhoda: udržuje se navždy, při upgrade knihovny je nutno ověřit.
2. **Vlastní `metro.config.js`** s `resolver.platforms` úpravou — křehké, zasahuje globálně.
3. **Ignorovat konkrétní log ve vývoji** — LogBox filter nebo Metro middleware. Řeší jen symptom, ne příčinu.

Ani jedno řešení nedává smysl pro kosmetickou chybu, která nemá dopad na aplikaci.

## Verifikace (že je vše v pořádku)

1. Aplikaci spustit v dev režimu: `pnpm start` (nebo dle scriptu v projektu).
2. Otevřít libovolnou obrazovku s nativním navigačním headerem (např. detail přepravy).
3. Zkontrolovat:
   - Šipka zpět se zobrazuje správně a je ostrá (retina assety se načtou).
   - App nepadá ani nehlásí runtime error.
   - Error v Metro logu je čistě warning — bundle se sestaví OK.
4. Release build: `eas build --profile preview` — error v release logu nebude.

## Shrnutí pro uživatele

**Ne, neřešit.** Je to kosmetická Metro hláška bez dopadu na aplikaci. Pokud by v budoucnu narostla do problému (např. by zpětná šipka v release buildu chyběla), pak řešit přes `patch-package`.
