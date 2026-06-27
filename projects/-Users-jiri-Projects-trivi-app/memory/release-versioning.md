---
name: release-versioning
description: "Jak verzovat a releasovat trivi-app: kde žijí verze, formát commitu vX.Y.Z (BUILD) a tagu vX.Y.Z.BUILD"
metadata: 
  node_type: memory
  type: project
  originSessionId: f2497997-6dbc-48ac-ba95-a93a32ff4909
---

Release konvence trivi-app (potvrzeno uživatelem 2026-06-17 při releasu v2.6.0).

**Verze se mění na 4 místech (vždy všechna):**
- `package.json` → `"version"`
- `android/app/build.gradle` → `versionName` (verze) + `versionCode` (build)
- `ios/trivi/Info.plist` → `CFBundleShortVersionString` (verze) + `CFBundleVersion` (build). Pozor: `CFBundleVersion` je **natvrdo číslo**, ne `$(CURRENT_PROJECT_VERSION)`, takže se musí měnit ručně.
- `ios/trivi.xcodeproj/project.pbxproj` → `CURRENT_PROJECT_VERSION` (build, **2× výskyt** – Debug i Release config).

**Build number** roste monotónně (App Store/Play vyžadují unikátní rostoucí). Při releasu se zvyšuje o 1. Aktuální stav: v2.6.0 = build 156. (Pozn.: build 155 byl commitnutý jako `v2.5.8 (155)`, ale nikdy netagovaný; poslední dřív releasnutý byl tag `v2.5.8.154`.)

**Commit message bumpu:** `vX.Y.Z (BUILD)`, např. `v2.6.0 (156)`. Bump je ve **vlastním commitu** (nic jiného). 
**Git tag:** `vX.Y.Z.BUILD`, např. `v2.6.0.156`.

**Why:** Celá historie repa používá `vX.Y.Z (BUILD)` (`v2.5.7 (153)`, `v2.5.8 (155)`…) a tagy `vX.Y.Z.BUILD`. To **přebíjí** globální pravidlo z ~/.claude/CLAUDE.md („commit message jen verze `v1.2.0`") – v tomto projektu se build dává i do commit message.

**How to apply:** Při releasu se zeptat na typ bumpu (patch/minor/major/only build) i na build number (default +1). Změnit verzi ve všech 4 souborech, commitnout samostatně jako `vX.Y.Z (BUILD)`, otagovat `vX.Y.Z.BUILD`. Push commitu i tagu až po potvrzení uživatelem (remote `d4w`). Build/test viz [[ios-build-setup]].
