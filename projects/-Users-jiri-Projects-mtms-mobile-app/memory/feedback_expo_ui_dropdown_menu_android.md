---
name: "@expo/ui jetpack-compose DropdownMenu — Host wrap + Compose Text"
description: DropdownMenu z @expo/ui/jetpack-compose v RN headerRight contextu vyžaduje Host matchContents wrap a native Compose Text v slotech, jinak se nerenderuje nebo se text láme po znacích
type: feedback
originSessionId: e0859ed9-5613-4f82-a262-bfb37737b2e3
---
`DropdownMenu` z `@expo/ui/jetpack-compose` má v RN view tree (zvlášť v `headerRight` z react-navigation) dva neintuitivní problémy:

**1. Sizing trigger areas**: Bez wrapu trigger se buď nerenderuje vůbec, nebo se roztáhne na fillMaxWidth (tenká lišta přes celou šířku). Řešení: wrap celého `DropdownMenu` do `<Host matchContents>` z `@expo/ui/jetpack-compose` a applikovat `size(W, H)` modifier na `DropdownMenu`. `Host matchContents` propíše Compose layout zpět do RN view tree.

**2. Text wrapping v menu items**: RN `Text` (z `@d4works/rnkit` nebo `react-native`) uvnitř `DropdownMenuItem.Text` slotu způsobí, že se text láme po jednotlivých znacích (popup je úzký jak prst). Řešení: použít Compose-native `Text` z `@expo/ui/jetpack-compose` místo RN Text.

```tsx
import { DropdownMenu, DropdownMenuItem, Host, Text as ComposeText } from '@expo/ui/jetpack-compose';
import { size } from '@expo/ui/jetpack-compose/modifiers';

<Host matchContents>
  <DropdownMenu modifiers={[size(44, 44)]} ...>
    <DropdownMenu.Trigger>
      <Pressable style={{ width: 44, height: 44, ... }}>
        <MaterialIcons ... />
      </Pressable>
    </DropdownMenu.Trigger>
    <DropdownMenu.Items>
      <DropdownMenuItem ...>
        <DropdownMenuItem.Text>
          <ComposeText>{label}</ComposeText>
        </DropdownMenuItem.Text>
      </DropdownMenuItem>
    </DropdownMenu.Items>
  </DropdownMenu>
</Host>
```

**Why:** Při refactoru `src/components/common/Menu/Menu.android.tsx` jsme prošli iteracemi: bez Hostu nic vidět nebylo (nebo se trigger roztáhl jako červená lišta přes celou šířku). S Hostem trigger fungoval, ale popup měl text lámaný po znacích. Native Compose Text fix to vyřešil.

**How to apply:** Vždy když děláš `DropdownMenu` (nebo jiný `@expo/ui/jetpack-compose` Compose komponent v RN view tree), wrapuj v `Host matchContents`. V slotech (`DropdownMenuItem.Text` apod.) použij Compose Text z `@expo/ui/jetpack-compose`, ne RN Text. Analog na iOS: `<Host matchContents>` a `SwiftText`/`SwiftImage`.
