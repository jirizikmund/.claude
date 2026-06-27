---
name: product-share-universal-links
description: "In-progress task — sdílení produktu (share tlačítko na detailu) + universal links; průzkum hotový, čeká na 2 rozhodnutí"
metadata: 
  node_type: memory
  type: project
  originSessionId: 35d42cd2-0fb0-4347-83ca-3735443c0784
---

**Úkol (zadání 2026-06-19):** Na detail produktu přidat vpravo nahoře ikonku **share**, která otevře nativní share menu a sdílí **URL produktu**. Navíc **universal links**: sdílí se standardní web link; když ho otevře telefon s nainstalovanou appkou, otevře se detail produktu rovnou v ní.

**Stav: PRŮZKUM HOTOVÝ, čeká na odpovědi uživatele na 2 otázky (níže). Nic se zatím neimplementovalo.**

## Zjištění z průzkumu (s cestami)

**Share tlačítko (přímočaré, celé v mobilním repu):**
- Detail = `src/components/screens/ScreenProduct.tsx`, hlavička přes `<StackScreenOptions title=... hideShadow />`. Ikonku přidat přes `rightElement={{ element: <ShareButton/> }}` (vzor: `src/components/screens/ScreenGallery.tsx` + `src/components/common/StackScreenOptions/index.tsx` podporuje variantu `element`).
- Header tlačítko vzor: `src/components/common/CloseButton/index.tsx` (`PressableView` + `Svg`).
- SVG ikony: složka `src/res/svg/common/`, registrace v `src/components/common/Svg/index.tsx` (`SVGS`). **Ikona „share" zatím NEEXISTUJE** — vytvořit (vzor `Exit.tsx`/`Filter.tsx`) nebo přes `yarn svg` z Figmy.
- Nativní sdílení = vestavěný `Share` z `react-native` (`Share.share({ message, url, title })`), žádná extra knihovna.
- Data v `ScreenProduct.tsx`: `productPreview` + `itemid` z params, `productDetail` z API. URL produktu = pole **`productDetail.url`** (existuje v API: `swagger.json` ~ř.2658, `src/api/syntex/swagger/models/ProductDetail.ts:77`; popis jen „Product URL"). **Pozor: `url` je jen na ProductDetail, ne na Product overview, a zatím se nikde nepoužívá.**
- Web doména: `STORE.appState.getWebdomain()` (fallback `API_DEFAULT_SERVER` v `src/constants/env.ts:79`). Pokud je `productDetail.url` relativní, prefixovat webdomainou; pokud absolutní, sdílet přímo.
- Tlačítko schovat/disable, dokud není `productDetail.url` načtené.

**Universal links (NEnakonfigurované, + externí závislosti):**
- `app.json`: bundle/package = `tv.syntex`; `ios.associatedDomains` má **jen `webcredentials:`** (8 domén: syntex.tv/.cz/.sk/.hu/.de/.si/.hr, syntexshop.es), **chybí `applinks:`**. Android **nemá žádné `intentFilters`**. `scheme: ["tv.syntex","fb..."]`. `experiments.typedRoutes: true`.
- expo-router: žádná `linking` config ani `+native-intent.tsx`. 
- Otevření detailu v appce je **podle číselného `itemid`**: `useBackgroundNavigateToProduct({ itemid })` v `src/utils/router/product.ts:27` → route `detail/[itemid]`. Tj. universal link MUSÍ umět z web URL získat `itemid`.
- Existující handling příchozích dat: jen z notifikací (`src/utils/firebase/useNotificationHandler.ts`, `data.itemid`→produkt, `data.link`→listing; viz `docs/architecture/notifications.md`).
- AASA (`/.well-known/apple-app-site-association`) + `assetlinks.json` **musí hostovat web** (s Team ID + Android SHA256) — není v repu, externí závislost.

## OTEVŘENÉ OTÁZKY (zeptat se uživatele, než plánovat dál)
1. **Formát `productDetail.url`** — absolutní vs relativní, a **obsahuje `itemid`?** (rozhoduje o sestavení share URL i o tom, jestli universal link umí otevřít detail bez backend lookupu slug→itemid). Ideálně si vyžádat konkrétní příklad URL.
2. **Universal links — hosting/sekvence:** AASA + assetlinks na webech (kdo/kdy). Doporučená varianta: **share tlačítko dodat hned** (funguje jako běžný odkaz), konfiguraci UL (app.json applinks + Android intentFilters + expo-router `+native-intent.tsx` mapování) připravit, ale ostré otevírání v appce poběží až web doplní soubory.

## Navržené rozdělení (k potvrzení)
- **Část A — Share tlačítko:** nová SVG ikona share + registrace, `ShareButton` (jako `CloseButton`), napojení do `ScreenProduct.tsx` headeru, share URL z `productDetail.url` (+ webdomain pokud relativní), `Share.share`. Plně v repu, shippable.
- **Část B — Universal links:** `app.json` (applinks do associatedDomains + Android intentFilters s autoVerify pro web hosty), expo-router `+native-intent.tsx` `redirectSystemPath` → `/(tabs)/homepage/detail/[itemid]` (parsovat itemid z URL — závisí na odpovědi #1), + externí AASA/assetlinks na webu.

**Why:** Rozpracovaný úkol přerušený před implementací; ať se příště naváže bez opakování průzkumu.
**How to apply:** Příště začít položením 2 otázek výše (URL formát + UL hosting/sekvence), pak psát plán a implementovat část A. Souvisí s [[feedback_keep_docs_updated]] (přidat doc, např. rozšířit `docs/features/products.md` nebo nový `docs/architecture/deep-linking.md`).
