# Plán: dokončit iOS release v21.16.0 (607)

## Context

Uživatel právě bumpnul verzi v lokálním repu na `21.16.0 (607)` (commit `3ac429d7` + tag `v21.16.0.607`) a spustil `yarn release:zoot:ios`, který otevřel Xcode workspace s production env a vyčištěným iOS buildem.

Otázka: má pokračovat lokálním Archive buildem v Xcode?

**Odpověď: ne.** Podle README (řádky 118–172) se produkční iOS build nedělá lokálně v Xcode — generuje ho **AppCenter** automaticky z větve `alpha`. Otevřený Xcode workspace slouží jen pro případnou ruční kontrolu (např. že Pody správně sedí, že se project konfiguruje pro správný flavor).

Lokální Xcode Archive bys dělal jen v případě, že:
- AppCenter je rozbitý a potřebuješ build manuálně
- chceš ověřit, že projekt vůbec jde sestavit pro Release konfiguraci

Pro standardní release stačí Xcode zavřít a pokračovat git workflow.

## Standardní release workflow (z README)

1. ✅ **Bump verze** — hotovo (`v21.16.0 (607)`, commit `3ac429d7`, tag `v21.16.0.607`)
2. **Push masteru a tagu na origin**
   ```bash
   git push origin master
   git push origin v21.16.0.607
   ```
3. **Force-push do `alpha` větve** (alpha = aktuální produkční snapshot, historie není zachovávaná)
   ```bash
   git branch alpha -D       # smazat lokálně, pokud existuje
   git branch alpha          # vytvořit z aktuálního masteru
   git push origin alpha -f
   ```
4. **AppCenter** — ručně spustit build pro `alpha` větev pro **všechny 4 aplikace**:
   - ZOOT iOS
   - ZOOT Android
   - BIBLOO iOS
   - BIBLOO Android
   - Po buildu se automaticky distribuuje do TestFlight (iOS) a Google Play alpha (Android)
5. **App Store Connect** (iOS)
   - vytvořit novou verzi tlačítkem "+"
   - vybrat build z TestFlight ("Add build")
   - počkat na "Whats new" texty (Anička)
   - **nastavit "Keep existing rating"** — nikdy neměnit, abys nepřišel o reviews
   - manuální vs. automatický release dle domluvy
6. **Google Play Console** (Android) — analogicky, viz README

## Pokud chceš přesto lokální Xcode Archive

Nepotřebuješ to pro release, ale postup je:
1. Xcode → vybrat schéma `ZootMobileApp`, destination `Any iOS Device (arm64)`
2. Edit Scheme → Archive → ověř, že Build Configuration je `Release`
3. Product → Archive
4. Po dokončení Organizer → Distribute App → App Store Connect → Upload

Bundle id pro zoot iOS: `com.zoot.zoot` (nastavuje to `tools/setup-project` z env `FLAVOR=zoot`).

## Kritické soubory (jen pro orientaci, neměníme je)

- `README.md:118-172` — release workflow
- `ios/ZootMobileApp.xcodeproj/xcshareddata/xcschemes/ZootMobileApp.xcscheme` — jediné schéma, ArchiveAction → Release
- `tools/setup-project` — nastavuje bundle ID podle FLAVOR

## Verifikace

- Po `git push origin alpha -f` zkontrolovat v AppCenter, že se tam alpha objevila a že lze spustit build
- Po dokončení AppCenter buildu zkontrolovat TestFlight, jestli se tam build objevil s číslem `21.16.0 (607)`

## Doporučení

Zavři Xcode (build tam nepotřebuješ) a pokračuj kroky 2–6 výše. Můžu rovnou pomoct s `git push` a vytvořením `alpha` větve.
