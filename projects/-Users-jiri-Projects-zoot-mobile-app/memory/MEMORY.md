# Zoot Mobile App - Memory

## Projekt
- React Native app (Android + iOS)
- Package manager: yarn (legacy projekt, nové projekty by měly být pnpm)
- Android package: `com.poqstudio.app.platform.zoot`
- Flavors: zoot, bibloo

## Klíčové soubory
- `src/utils/firebase.ts` — FCM setup, notifikace (foreground/background), remote config
- `src/App.tsx` — entry point, store rehydration, firebase init
- `src/navigation/navScreens/NavScreenDevMenu.tsx` — dev menu (zobrazuje FCM token atd.)
- `android/app/src/main/AndroidManifest.xml` — Android permissions
- `android/build.gradle` — ndkVersion (27.1.12297006)

## Aktuální práce: MOB-808 (notifikace)
- Nahrazení nativního NotificationChannelModule za @notifee/react-native (9.1.8)
- `notifee.requestPermission()` visí na Android 16 (API 36) — nikdy se neresolvne
- Aktuální workaround: fire-and-forget (`notifee.requestPermission().catch(() => {})`)
- Permission je na testovacím zařízení (2B121FDH2000R9) already granted
- Zbývá: ověřit že notifikace skutečně fungují, otestovat na zařízení kde permission NENÍ granted
- Zbývá: odstranit debug log z App.tsx (`DEBUG: about to call configureFirebase`)
- Zbývá: squashnout WIP commit do finálního

## Release — version bump checklist
Při bumpu verze vždy aktualizovat VŠECHNY tyto soubory:
1. `package.json` — pole `version`
2. `android/app/build.gradle` — `versionCode` (build number) + `versionName`
3. `ios/ZootMobileApp/Info.plist` — `CFBundleShortVersionString` + `CFBundleVersion`
4. `ios/ZootMobileAppTests/Info.plist` — `CFBundleShortVersionString` + `CFBundleVersion`

Flavor plisty (`Info.zoot.plist`, `info.bibloo.plist`) se neudržují v synchronizaci — neměnit.

Commit message formát: `v21.15.3 (597)` (verze + build number v závorce)

## MOB-810: 16KB page size
- Quick-fix (AGP 8.5.2, Gradle 8.7, compileSdk 35) nestačí — RN 0.74 .so mají 4KB alignment
- Jediné řešení: upgrade RN na 0.76+
- Detailní plán: viz `MOB-810-16kb-page-size.md`

## Debugging poznámky
- `configureFirebase()` v App.tsx nemá error handling — chyby se tiše polykají
- FCM token se ukládá do Redux storu přes `AuthData.setFcmToken()`
- Dev menu čte token z `AuthSessionSelectors.fcmToken`
