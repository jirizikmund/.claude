---
name: Zoot iOS app inspection findings
description: Key findings from Appium inspection of com.zoot.zoot on iPhone 16 Pro simulator
type: project
---

## App state on 2026-03-17 (multiple sessions)

**Why:** Inspected as part of verifying the running app on UDID 8DAAD0D4-4C92-43C2-9F7F-51D5CA3F82D0.

**How to apply:** Use these findings when inspecting or automating the Zoot iOS app.

## Notification permission dialog behavior

- Dialog text: "Aplikace „ZOOT" vám chce posílat oznámení" (Czech locale on simulator)
- Buttons: "Zakázat" (Deny) / "Povolit" (Allow)
- Dialog appears on ZOOT yellow splash background
- `appium_handle_alert` with buttonLabel "Povolit" FAILS with NoSuchAlertError when app is in crash state
- Direct XPath/accessibility id element search also fails during crash loop
- Dialog reappears on each relaunch while in crash loop (permission not persisted)

## App Setup Screen (first-run onboarding)

- Shown when Redux `appSetupFinished` flag is not set
- Source: `src/navigation/navScreens/NavScreenAppSetup.tsx`
- Page testID: `page-appSetup`
- Key element: button testID `button-finishSetup` (accessibility id strategy works)
- Country dropdown shows "România" by default
- All RN elements report `displayed: false` in XCUITest — use `accessibility id` with testID

## CRITICAL: Crash on setAppSetupFinished

Tapping `button-finishSetup` via Appium (which calls `GlobalSettingsData.setAppSetupFinished`)
caused the app to crash and enter a crash loop. The app crashes shortly after every relaunch
when it tries to initialize after this state write.

**Confirmed on 2026-03-17 across two separate inspection sessions.**

- After crash: app shows yellow ZOOT splash, then transitions to white blank screen
- A Redux dev toast "A non-serializable value was detected in th..." appears frozen at count 7
- The RN bridge becomes unresponsive: `appium_get_page_source` times out after 240s
- `appium_activate_app` does not help — app re-activates but stays on white blank screen
- processId changes each crash (76001 → 80048 → 89470 → 89986 → 96445 in session 1)
- WDA connection also drops (ECONNREFUSED 127.0.0.1:8100) during crash loop in session 1
- The crash loop persists indefinitely across Appium sessions

Workaround: The simulator needs to be reset or the Redux persist store cleared before
the app can be used in automation again. The store must be cleared BEFORE launching the app
(not via Appium — the app must not have run with the corrupted state).

**Do NOT attempt to tap button-finishSetup again without first resetting the simulator
or clearing the app's Redux persist store from the filesystem.**

## Appium session setup for Zoot iOS

```
platform: ios
appium:udid: 8DAAD0D4-4C92-43C2-9F7F-51D5CA3F82D0
appium:bundleId: com.zoot.zoot
appium:noReset: true
appium:usePreinstalledWDA: true
appium:automationName: XCUITest
```

WDA: prebuilt v11.4.1 at ~/.cache/appium-mcp/wda/11.4.1/extracted/WebDriverAgentRunner-Runner.app
