# Native dropdown menu pro headerRight na detailu přepravy (`@expo/ui`)

## Context

Na detailu přepravy (`src/app/transport-detail/[stageSetId].tsx`) je v `headerRight` aktuálně **dvě samostatná tlačítka** (zobrazená jen v dev mode): Download a Delete. Vizuálně to vypadá jako duo malých ikon vedle sebe.

Cíl: nahradit je **jediným trigger tlačítkem (`···` / `ellipsis`)**, které otevře **nativní iOS UIMenu**. Na iOS 26+ se UIMenu automaticky vykresluje v novém Liquid Glass stylu (matches Figma node 987-20854 — SwiftUI nativní komponenty dědí systémový vzhled vč. glass efektů). Tím:
- header je čistý (1 ikona místo 2)
- akce mají popisky a destructive style (delete je červený automaticky)
- prostor pro další dev akce v budoucnu bez bloatění headeru

## Knihovna

**`@expo/ui`** — Expo balíček s nativními primitivy postavenými přímo nad SwiftUI (iOS) / Jetpack Compose (Android). Poskytuje komponentu `Menu` (tap-to-open dropdown). Verze 55.0.1 je kompatibilní s naší Expo 55.0.13.

Klíčové výhody:
- 100% nativní SwiftUI Menu — automaticky dědí iOS 26+ Liquid Glass styl
- Žádný JS render menu UI
- Maintenance přes Expo team

Pozn.: `@expo/ui` je v preview stádiu — API se může mezi minor verzemi mírně měnit, ale 55.0.x je stabilní pro náš SDK.

## Změna

### 1) Instalace
```
npx expo install @expo/ui
```
Po instalaci je třeba **rebuildnout iOS app** (CocoaPods + native build), protože jde o native modul. V tomto projektu existuje `ios/` adresář (prebuild proběhl) → `cd ios && pod install` + rebuild přes `npx expo run:ios`.

### 2) `src/app/transport-detail/[stageSetId].tsx`

Refactor komponenty `HeaderRight` (řádky 88–146):

```tsx
import { Menu, Button as MenuButton } from '@expo/ui/swift-ui';

function HeaderRight(props: { stageSetId: string }) {
  const { stageSetId } = props;
  const isTransportDownloaded = STORE.transport.useIsTransportDownloaded({ stageSetId });
  const isDevMode = DevMode.useIsDevMode();
  const router = useRouter();

  const downloadTransport = useCallback(async () => {
    await STORE.transport.downloadTransportComplete({ stageSetId });
  }, [stageSetId]);

  const removeTransport = useCallback(() => {
    Alert.alert('[DEV] Smazat přepravu', 'Přeprava bude odstraněna z lokálního state.', [
      { text: 'Zrušit', style: 'cancel' },
      {
        text: 'Smazat',
        style: 'destructive',
        onPress: () => {
          if (EXECUTION_STORE.getExecutingStageSetId() === stageSetId) {
            EXECUTION_STORE.finishTransport_dangerously();
          }
          STORE.transport.removeTransport_dangerously({ stageSetId });
          router.back();
        },
      },
    ]);
  }, [stageSetId, router]);

  if (!isDevMode) return null;

  return (
    <Menu systemImage="ellipsis.circle">
      <MenuButton
        systemImage={isTransportDownloaded ? 'arrow.clockwise.circle' : 'arrow.down.circle'}
        onPress={downloadTransport}
      >
        {isTransportDownloaded ? 'Stáhnout znovu' : 'Stáhnout přepravu'}
      </MenuButton>
      <MenuButton systemImage="trash" role="destructive" onPress={removeTransport}>
        Smazat z lokálního state
      </MenuButton>
    </Menu>
  );
}
```

**Klíčové detaily:**
- `<Menu systemImage="ellipsis.circle">` — trigger je SF Symbol „ellipsis.circle"; tap otevře nativní UIMenu
- Children musí být komponenty z `@expo/ui` (`Button`, `Section`, `Divider`, `Toggle`, atd.) — proto importujeme `Button as MenuButton` aby nekonfliktoval s naším `Button`
- `systemImage` na Buttonu = SF Symbol vlevo od popisku
- `role="destructive"` na Smazat → automaticky červená barva (stejně jako .destructive UIAction)
- Loading state (`isDownloading`) **odstraněn** — Menu se zavře po výběru, indikátor stejně není vidět; pokud bude potřeba feedback, můžeme přidat globální banner/spinner později

**Pokud `@expo/ui` Menu nepodporuje custom React Node jako trigger** (pouze `systemImage` / `label`): `ellipsis.circle` by mělo být vizuálně blízko stávajícímu `MaterialIcons name="more-vert"` na Androidu i iOS. Pokud to bude problém, fallback je vykreslit MaterialIcon vedle pomocí kontejneru (View se Menu uvnitř bude pravděpodobně fungovat), případně zvážit `ContextMenu` s `Trigger` slotem (ale ten je primárně long-press).

## Critical files

**Modifikované:**
- `src/app/transport-detail/[stageSetId].tsx` — refactor `HeaderRight` (řádky 88–146)
- `package.json` / `yarn.lock` — nová dependency `@expo/ui`
- `ios/Podfile.lock` — nová Pod

**Nemodifikované, jen reference:**
- `STORE.transport.useIsTransportDownloaded`, `STORE.transport.downloadTransportComplete`, `STORE.transport.removeTransport_dangerously`, `EXECUTION_STORE.finishTransport_dangerously`, `DevMode.useIsDevMode` — existující, beze změny

## Verifikace

1. **Install + native rebuild**:
   - `npx expo install @expo/ui`
   - `cd ios && pod install`
   - Rebuild app v simulátoru (`npx expo run:ios`)
2. **TypeCheck**: `npx tsc --noEmit` → clean
3. **Funkční test (dev mode)**:
   - Otevřít detail přepravy → vpravo nahoře 1 ikona `ellipsis.circle`
   - Tap → otevře se nativní iOS UIMenu (na iOS 26+ s glass)
   - Tap "Stáhnout přepravu" → spustí download
   - Tap "Smazat" → confirmation Alert → smazání + `router.back()`
4. **Non-dev mode**: HeaderRight vrací `null` → žádná ikona
5. **iOS 26+ test**: glass material UIMenu (může vyžadovat real device s iOS 26)
6. **Android test**: stejné API → Jetpack Compose DropdownMenu

## Otevřené otázky

1. **Trigger vzhled**: stačí SF Symbol `ellipsis.circle`, nebo chceš jinou ikonu / text label vedle?
2. **`@expo/ui` je preview**: akceptuješ, že API se může mezi `55.0.x` patchi mírně měnit? (alternativně `@react-native-menu/menu` je stabilnější ale ne čistě Expo)
