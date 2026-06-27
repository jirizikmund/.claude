# Memory

- [iOS build setup](ios-build-setup.md) — RN 0.69 na moderním Xcode/Ruby: pody přes Ruby 3.3 + PATH, patch-package jen apply, iOS 26.5 simulátor
- [TRV-1830 upload workflow](trv-1830-document-upload-workflow.md) — dialog po přidání stránky dokladu, široké tlačítko Uložit, vypnutý autofocus; sdílené PhotoScreen/AccDocUploaded, stale-closure gotcha v Todo flow
- [Upload draft persistence](upload-draft-persistence.md) — lokální zapamatování rozpracovaného dokladu (přežije restart): utils/upload-draft.ts nad RNFS, kopírování souborů, TMA-422 onChange guardy (submittedRef + isEqual)
- [Release & versioning](release-versioning.md) — jak releasovat: verze ve 4 souborech, commit `vX.Y.Z (BUILD)`, tag `vX.Y.Z.BUILD`, build roste o 1 (přebíjí globální pravidlo)
