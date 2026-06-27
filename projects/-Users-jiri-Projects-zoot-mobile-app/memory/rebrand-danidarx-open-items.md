---
name: rebrand-danidarx-open-items
description: "Stav po rebrandingu na DaniDarx a release 21.17.0 (608) — zoot appka jen CZ/SK, zbývá úklid mrtvého kódu po phone verification"
metadata: 
  node_type: memory
  type: project
  originSessionId: fa2263d1-cdbf-42e5-a26d-3d6e0c9452d7
---

Rebrand Zoot/Digital People → **DaniDarx, s.r.o.** (oficiální název dle OR, IČO 24209139 — psáno dohromady) mergnut do masteru, release **v21.17.0 (608)** tagnut 11. 6. 2026.

**Důležitý fakt od uživatele (11. 6. 2026):** zoot verze aplikace existuje jen v CZ a SK — překladové stringy mimo cs/sk není potřeba řešit. Tím jsou uzavřené nálezy z code review ohledně `info@zoot.de`/`info@zoot.pl` v `_AppFeedbackEmail` i `_zoot.email = NOT_TRANSLATED` v 8/10 locale (cs/sk hodnoty jsou správně). Neflagovat znovu.

**Full CR rozsahu 607→608 proveden 12. 6. 2026 (max effort, 9 finderů + 11 verifikátorů + sweep): žádný release-blocking nález, build 608 schválen k public releasu.** Ověřeno čisté: tsc exit 0, auth slice není persistovaný, nav state se nepersistuje, žádné dangling reference (vč. string literálů/deeplinků/analytics), verze konzistentní (gradle bez productFlavors, iOS pbxproj používá bumpnutý Info.plist), emailTaken fix kompletní (19 registrací unikátních), clearErrors typo fix inertní, register flow end-to-end OK.

**Jediný zbývající otevřený bod — úklid mrtvého kódu po odstranění phone verification** (nabídnut, neproveden): metody/wrappery sendCode+verifyCode v `api/zoot/index.ts` (306–313, 683–690), záznamy userApi_sendCode + userApi_verifyCode + VERIFY_CODE_ERROR + MISSING_USER_PHONE v `errors.ts`, klíč `_API.verifyPhone.missingPhone` + 9 osiřelých locale klíčů ×10 souborů (POZOR: `'Telefonní číslo'` NEMAZAT — živé v ScreenShippingContact:258 + ScreenRegister:300), `TextInputCode` + barrel export (`components/index.ts:16`), celý soubor `src/hooks/input.ts` (usePhoneNumberInput; npm balíček `phone` zůstává — používá ho `utils/forms.ts`), no-op guard + `loginResult` binding v `NavScreenRegister.tsx:20-23` (samotný `await loginEmail(...)` MUSÍ zůstat — auto-login po registraci), 2 položky `ScreenName` unionu (`analytics/navigation.ts:208-209`), řádek v `navigation.md:48`.

Volitelné náměty z CR (low, neblokující): `unknownError: 'silent'` pro `userApi_emailTaken` (vzor `infoApi_versions`, omezí Sentry šum z debounced checku — chování ale stejné jako v 607); `{companyName}` jako default ICU proměnná v i18n wrapperu místo 10× hardcoded "DaniDarx, s.r.o." (drift se už jednou stal — sk mělo "ZOOT a.s."); `_AppFeedbackEmail` duplikuje `_zoot.email` (pre-existing); 11 cs / 2 sk zbylých `{flavor, select}` klíčů (pro zoot neškodné, bibloo = záměrný dual-listing ZOOT-branded buildů).

**Why:** mislabel `userApi_emailTaken` registrovaný pod `'userApi_verifyCode'` už byl opraven (commit "fix: register emailTaken api call under its own error scope") — teprve díky tomu je úklid bezpečný.

**How to apply:** úklid udělat jedním commitem na vyžádání. Pozn.: en.json je runtime no-op (en není v i18next resources ani AppLocale). Viz [[release-bump-checklist]].
