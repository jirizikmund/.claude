# Lokální zapamatování rozpracovaného dokladu (Upload tab)

## Context

Zadání od klienta: když uživatel v záložce **Nahrát** naskenuje/naimportuje stránky dokladu (a případně vyplní formulář), ale **neuloží doklad na server**, má se rozpracovaný doklad **uložit lokálně na zařízení** a při návratu na ikonu Nahrát — i po zabití/restartu appky — se mu **znovu objevit**.

Dnešní stav (ověřeno čtením kódu):
- Upload flow: `NavScreenUploadCapture` (`components/PhotoScreen`) → `NavScreenUploadDetail` (`components/common/accDoc/AccDocUploaded`). Stav žije v Redux slice `state.editing` (`uploadingFiles`, `uploadingDocument`, `isUploading`).
- `editing` **není** v redux-persist whitelistu (`src/store/index.ts:18` → jen `authSession`, `globalSettings`) → při restartu se stav ztratí.
- URI souborů míří do **dočasných** umístění (RNCamera tmp/, ImageResizer cache, DocumentPicker Inbox/`content://`) → i kdyby se stav persistoval, soubory po restartu nemusí existovat.
- Metadata formuláře se dnes do Reduxu **během editace neukládají** — `onChange` v `NavScreenUploadDetail.tsx:61` je zakomentované (TMA-422: po úspěšném uploadu se stará data znovu zapsala a předvyplnila příště).

**Rozhodnutí uživatele:** zapamatovat **stránky i pole formuláře** (poznámka, typ platby, kategorie, projekt, pobočka); obnova má proběhnout **tiše** (stránky se prostě objeví v pageru focení, zahození řeší stávající koš po stránkách).

## Přístup: vlastní draft manager nad RNFS (ne nested redux-persist)

Jádro úkolu není uložit JSON stav, ale **trvale uložit bajty souborů** do `RNFS.DocumentDirectoryPath` a při startu znovu poskládat URI (iOS absolutní prefix se mezi spuštěními/aktualizacemi mění). Proto:

- `editing` zůstává mimo redux-persist (žádná změna `persistConfig`).
- Bajty souborů kopírujeme do `DocumentDirectoryPath/upload-drafts/`, metadata držíme v malém JSON manifestu.
- Na startu appky draft načteme a naplníme Redux (`uploadingFiles` + `uploadingDocument`).
- Po úspěšném uploadu draft smažeme.
- Vzor RNFS práce přebíráme z `src/components/common/FilePreviewDialog/helpers.ts` (`DocumentDirectoryPath + subfolder`, `RNFS.mkdir`, `RNFS.exists`, `readFile('base64')`).

Tím se vyhneme: persistování `isUploading` (zaseknutý loader po killu) i `editingDocuments`, a iOS prefix řešíme rekonstrukcí cesty z basename.

## Nový soubor: `src/utils/upload-draft.ts`

Centrální draft manager. Konstanty `DRAFT_DIR = RNFS.DocumentDirectoryPath + '/upload-drafts'`, `MANIFEST_PATH = DRAFT_DIR + '/manifest.json'`.

Funkce (vše best-effort, chyby polykat → „žádný draft", nikdy neshodit upload/boot):
- `ensureDraftDir(): Promise<void>` — `RNFS.exists` + `RNFS.mkdir`.
- `persistDraftFile(file: UploadFile): Promise<UploadFile>` — zkopíruje `file.uri` do `DRAFT_DIR` pod **unikátním** jménem (`makeDraftFileName`), vrátí `{...file, uri: destPath, name: destName}`.
  - `file://`/holá cesta/tmp/cache → strip `file://`, `RNFS.copyFile` (ne `moveFile` — zdroj může být připnutý v živém `<Image>`/`<Pdf>` náhledu).
  - `content://` (Android import) → `RNFS.copyFile` v try; fallback `readFile(uri,'base64')` + `writeFile(dest,b64,'base64')`.
- `saveDraftManifest(files: UploadFile[], document: AccountingDocumentFromScanRequest): Promise<void>` — zapíše `{ files: [{name,type}], document }`. Zápisy **serializovat** přes in-module promise chain (rychlé multi-page focení).
- `loadDraft(): Promise<{ files: UploadFile[]; document?: AccountingDocumentFromScanRequest } | null>` — přečte manifest, každé `uri` **přepočítá** na `DRAFT_DIR + '/' + name` z aktuálního `DocumentDirectoryPath`, `RNFS.exists`-filtruje. Vrátí `null` pokud nezbyl žádný soubor (doc bez souborů = neplatný draft → ignorovat; tím je i případný stale manifest po uploadu neškodný).
- `removeDraftFile(uri: string): Promise<void>` — smaže jeden soubor + přepíše manifest.
- `clearDraft(): Promise<void>` — smaže celý `DRAFT_DIR` + manifest.
- `makeDraftFileName(name)` / `basename(p)` — vloží náhodný token před příponu (`mobile_…_a1b2c3.jpg`, `faktura_a1b2c3.pdf`); řeší kolize kamery ve stejné sekundě i opakovaný import stejného jména (důležité, `REPLACE_UPLOADING_FILE` páruje podle `name`).

## Změny po souborech

**`src/utils/upload-draft.ts`** — nový (viz výše).

**`src/actions/index.ts`**
- `addUploadingFile` (345) — soubory ztrvalit:
  - bez `compressing` (iOS kamera + import obě platformy): `persistDraftFile` **před** dispatchem, dispatch `ADD_UPLOADING_FILE` s trvalým souborem, pak `saveDraftManifest(getUploadingFiles(getState()), getUploadingDocument(getState()))`.
  - Android (`compressing`): zachovat dvoufázový flow (instant preview přes původní uri), po `ImageResizer` zavolat `persistDraftFile` na **komprimovaný** uri a dispatch `REPLACE_UPLOADING_FILE`; pak `saveDraftManifest`. `name` musí zůstat stejné mezi ADD a REPLACE (kvůli párování v `editing.ts:54`) → unikátní jméno vlastní kamera (viz Camera.tsx), `persistDraftFile` použije existující `name`.
- `removeUploadingFile` (382) — přečíst `getUploadingFiles(getState())[index]`, dispatch `REMOVE_UPLOADING_FILE`, `removeDraftFile(removed.uri)`, `saveDraftManifest(...)`.
- Nový thunk `restoreUploadDraft()` — `const draft = await loadDraft()`; pokud `draft`, dispatch `SET_UPLOADING_FILES` (files) a `CHANGE_UPLOADING_DOCUMENT` (document). Volat jen pro přihlášeného uživatele.
- Nový thunk `clearUploadDraft()` — wrapuje `clearDraft()`.
- `logout` (314) — přidat `dispatch(clearUploadDraft())` (privacy na sdíleném zařízení).
- Action union (~71) — přidat `{ type: 'SET_UPLOADING_FILES'; uploadingFiles: UploadFile[] }`.

**`src/reducers/editing.ts`**
- `case 'SET_UPLOADING_FILES': return { ...state, uploadingFiles: action.uploadingFiles }` (nesahat na `isUploading`).
- `case 'LOGOUT': return { ...initialState }` (vyčistit i in-memory stav při odhlášení).

**`src/components/PhotoScreen/Camera.tsx`**
- `generateFileName` (208) — přidat náhodný token (kolize ve stejné sekundě).
- `importPicture` (140) — přidat `copyTo: 'documentDirectory'` do `DocumentPicker.pick` a použít `uri: reso.fileCopyUri ?? reso.uri` (spolehlivý `file://` místo `content://`; `persistDraftFile` pak stejně zkopíruje do `upload-drafts/`).

**`src/navigation/AppNavigator/BottomTabNavigator/TabUpload/NavScreenUploadDetail.tsx`** — persistence formuláře, TMA-422-safe:
- Zavést `submittedRef = useRef(false)`.
- **Znovu zapnout** `onChange={handleChange}`. `handleChange(doc)`:
  - `if (submittedRef.current) return`
  - `if (_.isEqual(getUploadingDocument(getState()), doc)) return` ← **zabrání render-loopu** (reducer dělá `Object.freeze({...})` → nová reference pokaždé)
  - `dispatch(changeUploadingDocument(doc))` (in-session)
  - debounced `saveDraftManifest(getUploadingFiles(getState()), doc)` (restart)
- `handleSubmit`: `submittedRef.current = true` **před** `await uploadNewAccDoc(...)`; na `success` → `await clearDraft()` + `onNavigateBack()` (ref necháme `true`, obrazovka se odmountuje → stale `onChange` během reset-renderu se přeskočí); na `error` → `showError` + `submittedRef.current = false` (povolit retry persistenci).

**`src/App.tsx`** — v `onStoreRehydrate` (66) po `checkAppVersion()` přidat `if (isLoggedIn(REDUX_INSTANCE.getState())) await REDUX_INSTANCE.dispatch(restoreUploadDraft())`.

**Beze změny:** `src/store/index.ts` (persistConfig), `components/PhotoScreen/index.tsx` (pager zobrazí obnovené stránky sám), Todo flow (`ScreenToDoUploadAccDoc` má vlastní stav + route params — `clearDraft` je v Upload-tab handleru, ne ve sdíleném `uploadNewAccDoc`), `AccDocUploaded/pure.tsx` (existující `onChange` useEffect na ř. 142 stačí, jen mu znovu předáme `onChange`).

## Edge cases / gotchas

1. **Render-loop** při re-enable `onChange` → ošetřen `_.isEqual` guardem v `handleChange` (lodash `_` už importován v pure.tsx; v Detailu doimportovat).
2. **TMA-422 předvyplnění po uploadu** → `submittedRef` zůstává `true` přes celou success-cestu až do odmountování; stale `onChange` se přeskočí i na disku (před zápisem) i v Reduxu.
3. **`isUploading` zaseknutý loader po killu** → `isUploading` se nikdy nepersistuje ani neobnovuje; `initialState.isUploading=false`.
4. **iOS prefix drift** → manifest drží jen basename+type; `loadDraft` skládá cestu z aktuálního `DocumentDirectoryPath` + `RNFS.exists` filtr.
5. **`content://` (Android import)** → `copyTo:'documentDirectory'` + `fileCopyUri`; fallback base64 read/write v `persistDraftFile`.
6. **`REPLACE_UPLOADING_FILE` páruje podle `name`** → unikátní `name` vlastní kamera (Camera.tsx), `persistDraftFile` ho zachová.
7. **Kolize jmen** → `makeDraftFileName` přidá náhodný token.
8. **Todo flow** → nedotčen (cleanup jen v Upload-tab `handleSubmit`).
9. **Privacy** → `clearUploadDraft()` na logout + `LOGOUT` case v `editing.ts`; `restoreUploadDraft` jen pro přihlášeného.
10. **Stale manifest po uploadu** (kdyby přesto vznikl) → neškodný: `loadDraft` vrátí `null`, když nejsou soubory na disku.
11. **Kill při psaní poznámky před blurem** → in-progress text ztracen (poznámka se ukládá na blur přes `titleDebounced`); akceptováno, odpovídá dnešnímu debounce chování.

## Verifikace

iOS build/spuštění viz `[[ios-build-setup]]` (`yarn pods`, `yarn ios`). Kamera v simulátoru nefunguje → testovat přes **import** (download ikona vlevo dole na obrazovce focení); kamerový průchod jen na fyzickém zařízení.

1. **Restart se stránkami:** Nahrát → import 1–2 stránek → vyplnit poznámku/typ platby → **bez uložení** appku zabít (swipe z přepínače aplikací) → znovu otevřít → záložka Nahrát ukáže stránky v pageru; po šipce vpravo je formulář předvyplněný.
2. **Tichá obnova:** žádný dialog; stránky prostě jsou tam.
3. **Cleanup po uploadu:** nahrát doklad → po úspěchu se vrátí na prázdný foťák; další otevření = prázdný formulář (TMA-422 drží); `DocumentDirectoryPath/upload-drafts/` je prázdný.
4. **Error neztratí draft:** vyvolat chybu uploadu (letmód) → stránky i pole zůstanou, lze retry.
5. **Zahození:** koš maže stránky po jedné i z disku; po smazání poslední se nic neobnoví.
6. **Logout:** odhlásit → draft soubory smazány; po přihlášení čistý stav.
7. **Multi-page race:** rychle naimportovat 3 stránky za sebou → po restartu všechny 3 (serializovaný zápis manifestu).
8. Ověřit Android i iOS (rozdílné cesty/komprese/`content://`).
