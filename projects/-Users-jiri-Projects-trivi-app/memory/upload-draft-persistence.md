---
name: upload-draft-persistence
description: Lokální zapamatování rozpracovaného dokladu v Upload tabu (přežije restart) — kde to žije a na co pozor
metadata: 
  node_type: memory
  type: project
  originSessionId: f2497997-6dbc-48ac-ba95-a93a32ff4909
---

Funkce (hotová 2026-06-17, commit `[TRV-1923]`, vyšla v releasu v2.6.0 / build 156): v Upload tabu ("Nahrát") se rozpracovaný doklad (stránky i pole formuláře) ukládá lokálně a po zabití/restartu appky se tiše obnoví; po úspěšném uploadu na server se draft smaže. Navazuje na [[trv-1830-document-upload-workflow]]. Release konvence viz [[release-versioning]].

**Architektura:**
- Jádro: nový util `src/utils/upload-draft.ts` (draft manager nad RNFS). NEpoužívá redux-persist — `editing` slice zůstává mimo whitelist. Důvod: hlavní problém není uložit JSON stav, ale **trvale uložit bajty souborů** (URI z kamery/ImageResizer/DocumentPicker míří do tmp/cache a OS je po killu smaže). Bajty kopírujeme do `DocumentDirectoryPath/upload-drafts/`, metadata do `manifest.json`.
- iOS gotcha: absolutní prefix `DocumentDirectoryPath` se mezi spuštěními/aktualizacemi mění → manifest drží jen basename+type, `loadDraft` skládá cestu z aktuálního prefixu + `RNFS.exists` filtr. URI se ukládá s `file://` (RN `<Image>`/`<Pdf>` to na iOS chce).
- Soubory se ztrvalí v `addUploadingFile`/`removeUploadingFile` thunkách (`src/actions/index.ts`); na Androidu až po kompresi (po `REPLACE_UPLOADING_FILE`, který páruje podle `name` → jména musí být unikátní už od vzniku, proto `makeDraftFileName` přidává token v `Camera.tsx`). Import: `DocumentPicker` `copyTo:'cachesDirectory'` + `fileCopyUri` (spolehlivý `file://` místo `content://`).
- Obnova: `restoreUploadDraft()` v `onStoreRehydrate` (`src/App.tsx`), guard na `isLoggedIn`; dispatchne `SET_UPLOADING_FILES` + `CHANGE_UPLOADING_DOCUMENT`. Reducer `editing.ts` má nové case `SET_UPLOADING_FILES` (nesahá na `isUploading`) a `LOGOUT` (reset). Cleanup: `clearDraft()` v `NavScreenUploadDetail.handleSubmit` na success (NE ve sdíleném `uploadNewAccDoc` — Todo flow nedotčen) + `clearUploadDraft()` na logout.

**TMA-422 (důležité při dalších úpravách formuláře):** `onChange` v `NavScreenUploadDetail.tsx` byl historicky vypnutý, protože se po úspěšném uploadu provolal se starými hodnotami a předvyplnil příští doklad. Nově je znovu zapnutý, ale chráněný: `submittedRef` (po zahájení submitu se onChange přeskočí, drží přes celou success cestu až do odmountování) + `isEqual` guard (reducer dělá `Object.freeze({...})` → nová reference pokaždé → bez guardu render-loop). Kdokoli kdo bude znovu sahat na onChange/persistenci metadat musí oba guardy zachovat.

**Concurrency:** zápisy manifestu jsou serializované přes in-module `writeChain` v upload-draft.ts; `clearDraft` jde taky přes `writeChain` (jinak by doběhlý zápis vzkřísil smazaný adresář). Vše best-effort (chyby polykáme), aby se neshodil upload ani boot.

Build/test viz [[ios-build-setup]]; kamera v simulátoru nefunguje → testovat přes import.
