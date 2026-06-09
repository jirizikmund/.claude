---
name: Syntex app contains no third-party advertising
description: Verified fact about Syntex app — no ad SDKs integrated, all promotional content is first-party merchandising. Relevant for App Store Connect Age Rating and App Review replies.
type: project
originSessionId: 7e08cba3-2920-4360-989e-0ea062499dc1
---
Syntex (syntex-mobile-app) does **not** integrate any third-party advertising SDK — verified against `package.json` and `libs/@d4works/rnkit/package.json`: no AdMob / google-mobile-ads, Meta Audience Network, AppLovin, Unity Ads, IronSource, Chartboost, Vungle, Mintegral, Tapjoy, AdColony, InMobi. All banners, homepage widgets, deals and product highlights are first-party merchandising of the store's own catalog.

**Why:** On 2026-04-14 Apple App Review flagged the submission with "App Review Guideline Issue — automated analysis indicates the app may include advertising but Age Rating Advertising descriptor is set to No." This is a false positive from their automated scanner, likely triggered by in-app promotional banners/deal widgets.

**How to apply:** The Age Rating "Advertising" descriptor in App Store Connect is correctly set to **No** and should stay that way. If a future submission gets flagged again, reply via Resolution Center confirming the app has no third-party ads (draft reply was prepared in the 2026-04-14 conversation). Also keep a clarifying note in App Store Connect → app version → **App Review Information → Notes** stating "The app does not contain third-party advertising; all promotional content is first-party merchandising of our own e-commerce catalog." to preempt the scanner on future submissions.
