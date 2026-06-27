---
name: trv-1830-document-upload-workflow
description: "TRV-1830 — dialog po přidání stránky dokladu, široké tlačítko Uložit, vypnutý autofocus; kde to žije a na co pozor"
metadata: 
  node_type: memory
  type: project
  originSessionId: 197f483b-ac56-42ad-b5d7-2c2b1b501510
---

TRV-1830 (dokončeno 2026-06-16): vylepšení workflow nahrávání dokladů v RN appce trivi-app. Commit `[TRV-1830] Improve document upload workflow`.

**Co se přidalo:**
- Po přidání každé stránky dokladu (vyfocení i import souboru) se zobrazí dialog „Chcete přidat další stránku dokladu?" — „Ano" vrátí na foťák (`scrollToEnd` Pageru), „Ne, pokračovat na uložení" jde na ukládací obrazovku. Logika v `components/PhotoScreen/index.tsx` (`onGetPictureFinish`).
- Obrazovka „Nahrát doklad" (`components/common/accDoc/AccDocUploaded/pure.tsx`): široké žluté tlačítko „Uložit" + fajfka (`Button type="big_yellow" icon="tick"`) místo kulaté ikony; vypnutý autofocus pole Poznámka (klávesnice po příchodu nenaskočí, `autoFocus={false}`).

**Architektura (na co pozor při dalších úpravách):**
- Obě capture obrazovky (`NavScreenUploadCapture` – Redux; `NavScreenTodoCaptureAccDoc` – hook `useCameraCapture`) renderují sdílený `PhotoScreen`. Obě „Nahrát doklad" obrazovky (`NavScreenUploadDetail` z Upload tabu; `ScreenToDoUploadAccDoc` z Todo tabu) renderují sdílený `AccDocUploaded/pure.tsx`. Změny v těchto sdílených komponentách platí pro oba flowy. `AccDocUploaded` se používá i v readonly/overview náhledech — `renderSubmitButton` je za guardem `readonly || editing`.
- `Pager` (`components/common/Pager`) je class komponenta; přidána veřejná metoda `scrollToEnd`. `render()` používá iOS ScrollView i na Androidu (Android viewpager větev je mrtvá).
- **Gotcha (stale closure):** v Todo flow `navigateToUploadDetail` předává `files` přes route params. Protože dialog volá navigaci až po `await`, musí se aktuální `files` číst přes `useRef` (`filesRef.current`), jinak by se ztratila naposledy přidaná stránka. Upload tab tím netrpí (čte z Reduxu na cílové obrazovce). Pro jakoukoli další async akci spuštěnou z dialogu platí totéž.
- `ConfirmDialog.show` (`utils/ConfirmDialog`) má volitelné `confirmStyle`/`cancelable` (default `'destructive'`/`false`) pro nedestruktivní dialog; stávající destruktivní dialogy beze změny.
- Překlady: `photo.addPageDialog.{title,confirm,cancel}` a `photo.saveLabel` v `i18n/locales/{cs,en}.js`.

**Testování:** foťák v iOS simulátoru nefunguje — dialog i ukládací obrazovku otestuješ přes tlačítko import (download vlevo dole) na obrazovce focení; kamerový průchod jen na fyzickém zařízení. Build/spuštění viz [[ios-build-setup]].
