# TRV-1830 — Vylepšení workflow nahrávání dokladů

## Context

Revize workflow nahrávání dokladů odhalila tři UX problémy:
1. **Vícestránkové doklady jsou skrytá funkce** — uživatelé netuší, že další stránku přidají swipnutím doleva na foťák. Řešení: po přidání každé stránky se zeptat dialogem, zda chtějí přidat další.
2. **Klávesnice zakrývá tlačítko uložit** — na obrazovce „Nahrát doklad" je automaticky zaostřené pole Poznámka, takže naskočí klávesnice a překryje tlačítko pro uložení. Uživatel pak může mít dojem, že je doklad uložený, i když není.
3. **Tlačítko uložit je nenápadné** — žlutá kulatá ikona fajfky bez popisku. Přidat text „Uložit".

Cílem je zviditelnit přidání další stránky i samotné uložení, aby uživatelé nedokončený doklad neopustili v domnění, že je hotový.

## Potvrzená rozhodnutí (od uživatele)

- **Dialog se zobrazí po přidání stránky oběma způsoby** — vyfocením i importem souboru.
- **Text dialogu** je obecný: „Chcete přidat další stránku dokladu?" (sedí na focení i import).
- **Tlačítko uložit** = široké žluté tlačítko „Uložit + fajfka na jedné řádce", **pevná šířka, plovoucí vpravo dole** (zachová dnešní umístění, jen širší s textem).

## Klíčová zjištění z průzkumu

- **Obě capture obrazovky** (`NavScreenUploadCapture` — Upload tab, Redux; `NavScreenTodoCaptureAccDoc` — Todo tab, hook `useCameraCapture`) renderují sdílený `components/PhotoScreen`. Změna dialogu v `PhotoScreen` pokryje oba flowy.
- **Obě obrazovky „Nahrát doklad"** (`NavScreenUploadDetail` a `ScreenToDoUploadAccDoc`) renderují sdílený `components/common/accDoc/AccDocUploaded/pure.tsx`. Změny B a C v něm pokryjí oba flowy. `renderSubmitButton` se vykreslí jen v editovatelném režimu (vrací `null` při `readonly || editing`), takže readonly/overview náhledy zůstanou nedotčené.
- **`Pager`** (`components/common/Pager/index.tsx`) je class komponenta bez imperativního scroll API; `render()` vrací vždy iOS variantu (`<ScrollView horizontal pagingEnabled>`) na obou platformách. Pro „Ano → zpět na foťák" doplníme veřejnou metodu `scrollToEnd`.
- **`Button`** (`components/common/Button/index.tsx`) typu `big_yellow` umí `title` + `icon` zároveň — při obojím jde ikona automaticky doprava → „Uložit ✓" na jedné řádce. `icon="tick"` = černá fajfka. Podporuje `shadow`, `disabled`, auto-šířku dle obsahu.
- **autoFocus** na poli Poznámka: `pure.tsx:197` `autoFocus={props.editing || title ? false : true}` — `true` nastane jen při příchodu na nový upload (editing=false, prázdný title). Nastavením na `false` se opraví přesně tento případ, ostatní režimy zůstanou beze změny.
- **`ConfirmDialog.show`** (`utils/ConfirmDialog/index.tsx`) vrací `Promise<boolean>` přes `Alert.alert`, ale natvrdo dává `style:'destructive'` na potvrzovací tlačítko (červené) — pro náš nedestruktivní dialog ho musíme zneškodnit přidáním volitelného parametru.

## Změny po souborech

### 1. `src/utils/ConfirmDialog/index.tsx` — rozšířit o nedestruktivní variantu
Přidat volitelné parametry `confirmStyle` (default `'destructive'`) a `cancelable` (default `false`), aby stávající 3 volající (`NavScreenAccDocLines`, `NavScreenTodoCaptureAccDoc` discard, `UnmatchedPaymentItem` handover) zůstali beze změny:
```ts
async function show(params: {
  title: string; message?: string; confirm: string; cancel: string
  confirmStyle?: AlertButton['style']  // default 'destructive'
  cancelable?: boolean                 // default false
}): Promise<boolean> {
  return new Promise(resolve => {
    Alert.alert(params.title, params.message, [
      { text: params.cancel, onPress: () => resolve(false) },
      { text: params.confirm, onPress: () => resolve(true), style: params.confirmStyle ?? 'destructive' },
    ], { cancelable: params.cancelable ?? false })
  })
}
```

### 2. `src/components/common/Pager/index.tsx` — imperativní `scrollToEnd`
- Přidat `scrollViewRef = React.createRef<ScrollView>()`, připojit `ref={this.scrollViewRef}` na `<ScrollView>` v `renderPager_ios`.
- Veřejná metoda:
```ts
public scrollToEnd = (animated = true) => {
  this.scrollViewRef.current?.scrollToEnd({ animated })
  const last = this.getPageCount() - 1
  this.setState({ currentPage: last })
  this.props.onPageChange?.(last)   // sync indexu v PhotoScreen (programový scroll nemusí vyvolat onMomentumScrollEnd)
}
```
Stejné widthy stránek + `pagingEnabled` zaručí, že max offset = poslední (foťák) stránka.

### 3. `src/components/PhotoScreen/index.tsx` — dialog po přidání stránky
- `const pagerRef = useRef<Pager>(null)`, předat `ref={pagerRef}` do `<Pager>`.
- Importovat `ConfirmDialog` a `I18n`.
- Přepsat `onGetPictureFinish` na async; dialog se zobrazí **bez ohledu na mode** (foto i import):
```ts
const onGetPictureFinish = useCallback(async (file?: UploadFile) => {
  if (!file) { setIsGettingPicture(false); return }
  props_addUploadingFile(file)
  setIsGettingPicture(false)
  const addAnother = await ConfirmDialog.show({
    title: I18n.t('photo.addPageDialog.title'),
    confirm: I18n.t('photo.addPageDialog.confirm'),  // „Ano"
    cancel: I18n.t('photo.addPageDialog.cancel'),    // „Ne, pokračovat na uložení"
    confirmStyle: 'default',                         // nedestruktivní
  })
  if (addAnother) {
    pagerRef.current?.scrollToEnd(true)   // zpět na stránku s foťákem + importem
  } else {
    props.navigateToUploadDetail()        // pokračovat na „Nahrát doklad"
  }
}, [props_addUploadingFile, props.navigateToUploadDetail])
```
Dialog je `cancelable: false` (default) → uživatel musí zvolit, čímž se eliminuje „myslel jsem, že je uložený". `Camera.tsx` zůstává beze změny (druhý arg `mode` se ignoruje).

### 4. `src/components/common/accDoc/AccDocUploaded/pure.tsx` — klávesnice + tlačítko
- **B (řádek 197):** `autoFocus={false}` — klávesnice po příchodu zůstane zavřená.
- **C (`renderSubmitButton`, ř. 294-313):** nahradit kulatý `IconButton` širokým `Button`:
```tsx
<View style={[styles.submitButtonWrapper, { bottom: props.safeContentSpace ? 0 : 15 }]}>
  <Button
    type="big_yellow"
    title={I18n.t('photo.saveLabel')}   // „Uložit"
    icon="tick"                          // fajfka vpravo
    shadow
    onPress={handleSubmit}
    disabled={props.uploadingIsUploading}
  />
  {props.safeContentSpace && <SafeContentSpace position="bottom" />}
</View>
```
- Importy: do `import { ... } from 'components'` přidat `Button`, odebrat nepoužitý `IconButton`. Odstranit nepoužitý styl `styles.submitButton` (kulatý stín nahrazuje `shadow` prop `Button`). Bez explicitní `width` se tlačítko přizpůsobí obsahu (užší, vpravo dole — dle volby).

### 5. + 6. Překlady — `src/i18n/locales/cs.js` a `en.js`
Do bloku `photo:` (cs.js ~ř. 760, en.js ~ř. 769) přidat:
```js
// cs.js
addPageDialog: {
  title: 'Chcete přidat další stránku dokladu?',
  confirm: 'Ano',
  cancel: 'Ne, pokračovat na uložení',
},
saveLabel: 'Uložit',
```
```js
// en.js
addPageDialog: {
  title: 'Do you want to add another document page?',
  confirm: 'Yes',
  cancel: 'No, continue to save',
},
saveLabel: 'Save',
```

## Rizika a okrajové případy

- **Časování scrollToEnd:** nová stránka se vyrenderuje hned po `addUploadingFile`, ještě než uživatel klepne v nativním `Alert` (ten je sám asynchronní odklad). Po „Ano" je layout hotový a `scrollToEnd` dosedne na foťák. Pojistka `requestAnimationFrame` jen kdyby tester viděl místo foťáku poslední fotku.
- **Index/paginator po programovém scrollu:** `scrollToEnd` synchronizuje `currentPage` + volá `onPageChange`, takže delete-tlačítko a tečky paginátoru zůstanou konzistentní.
- **Android:** `Pager.render()` používá iOS ScrollView i na Androidu → `scrollToEnd` funguje stejně. `Alert` styly (`destructive`/`default`) Android ignoruje, sémantika (confirm=Ano) je platformně nezávislá; `cancelable:false` blokuje i Android back.
- **Žádná regrese readonly/editing náhledů:** C je za guardem `readonly || editing`; B měnilo chování jen u nového uploadu. Overview/edit dokladu renderují stejný `pure.tsx`, ale s `readonly`/`editing` → nezasaženo.
- **Stávající destruktivní dialogy** (zahodit nový doklad, předat platbu) zůstanou červené a beze změny díky defaultu `confirmStyle = 'destructive'`.

## Ověření (`yarn ios`)

1. Upload tab → vyfotit stránku → objeví se dialog „Chcete přidat další stránku dokladu?", nelze zavřít klepnutím mimo.
2. „Ano" → vrátí na živý foťák (foťák + ikona importu, poslední tečka paginátoru), ne na vyfocenou fotku.
3. Importovat soubor (tlačítko download) → dialog se zobrazí i zde; „Ano" → zpět na foťák.
4. „Ne, pokračovat na uložení" → obrazovka „Nahrát doklad" se všemi stránkami ve výběru.
5. Po příchodu na „Nahrát doklad" **klávesnice nenaskočí**, pole Poznámka není zaostřené; klepnutím se zaostří a klávesnice se otevře.
6. Tlačítko **„Uložit ✓"** je široké, žluté, vpravo dole, text + fajfka na jedné řádce; neoříznuté safe-area (test na zařízení s notchem i bez).
7. Klepnutí na „Uložit" doklad uloží jako dosud; během uploadu je disabled + overlay loader.
8. Todo tab (příloha k platbě): zopakovat 1–7; ověřit `safeContentSpace` layout a že discard dialog na back-tlačítku funguje nezávisle.
9. Readonly/overview náhled a edit existujícího dokladu: žádné tlačítko Uložit, žádná auto-klávesnice.
10. Stávající destruktivní dialogy (zahodit doklad, předat platbu) stále červené a beze změny.

## Soubory k úpravě
- `src/utils/ConfirmDialog/index.tsx`
- `src/components/common/Pager/index.tsx`
- `src/components/PhotoScreen/index.tsx`
- `src/components/common/accDoc/AccDocUploaded/pure.tsx`
- `src/i18n/locales/cs.js`
- `src/i18n/locales/en.js`
