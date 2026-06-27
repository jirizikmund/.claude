---
name: ios-build-setup
description: "Jak na tomto stroji buildit iOS aplikaci (Ruby 3.3 pro CocoaPods, PATH, patch-package omezení)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 197f483b-ac56-42ad-b5d7-2c2b1b501510
---

trivi-app je React Native 0.69.0 (2022) a na moderním toolchainu (Xcode 26.x, Homebrew Ruby 4.x, Yarn 4) má kaskádu nekompatibilit. Nutný postup pro iOS build na tomto stroji:

- **CocoaPods musí běžet na Ruby 3.3**, ne na systémovém `/usr/bin/ruby` 2.6.10 ani na Homebrew Ruby 4.x. Ruby 4.0 láme RN 0.69 codegen (`use_react_native_codegen!` → `wrong number of arguments`) i CocoaPods. Nainstalováno: `brew install ruby@3.3` + `gem install cocoapods -v 1.16.2` pod tímto Ruby.
- **Ten PATH je už zadrátovaný v yarn skriptech** (`ios` a nový `pods` v package.json), takže stačí `yarn pods` (= pod install) a `yarn ios`. PATH je `/opt/homebrew/opt/ruby@3.3/bin:/opt/homebrew/lib/ruby/gems/3.3.0/bin:$PATH`. Při ručním volání `pod` mimo yarn ho přidej taky, jinak se chytí Homebrew Ruby 4.x a padá to.
- **patch-package: funguje jen APPLY (postinstall), NE generování.** Yarn 4 lockfile (`__metadata: version: 8`) neumí naparsovat patch-package 6.4.7 (`Unknown token`) ani 8.x (`--ignore-scripts` chyba). Nové patche generovat ručně: `git diff --no-index` proti originálům staženým z `https://unpkg.com/react-native@0.69.0/<cesta>`, pak sedem přepsat hlavičky cest na `a/node_modules/react-native/<cesta>`.
- **Simulátor:** Xcode 26.5 neakceptuje starší iOS runtime (26.2) — vyžaduje stažení iOS 26.5 platformy (Settings → Components nebo `xcodebuild -downloadPlatform iOS`). Bez ní `xcodebuild` nevidí žádný eligible simulátor.

Konkrétní build fixy (boost URL, boost C++17 makra, Yoga `-Werror`) jsou v gitu — commit `build: fix iOS pods build on Xcode 26`.
