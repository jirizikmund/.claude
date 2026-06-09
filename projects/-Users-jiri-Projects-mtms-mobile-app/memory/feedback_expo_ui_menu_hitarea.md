---
name: "@expo/ui swift-ui Menu — hit area se string labelem"
description: SwiftMenu se string labelem má tap area jen na bounding boxu textu; pro rozšíření tap area předej custom JSX label s frame + contentShape modifiers
type: feedback
originSessionId: e0859ed9-5613-4f82-a262-bfb37737b2e3
---
`SwiftMenu` z `@expo/ui/swift-ui` se `label="text"` propem má hit area pouze na bounding boxu toho textu — `frame()` ani `contentShape()` aplikované přes `modifiers` na samotném `SwiftMenu` tap area NErozšíří (aplikují se na vnější container, ne na label).

**Řešení:** předat label jako custom JSX node (např. `SwiftImage` nebo `SwiftText`) a `frame` + `contentShape` aplikovat přímo na něj:

```tsx
<SwiftMenu
  label={
    <SwiftImage
      systemName="ellipsis.circle.fill"
      modifiers={[
        frame({ width: 44, height: 44 }),
        contentShape(shapes.circle()),
      ]}
    />
  }
>
  {/* items */}
</SwiftMenu>
```

**Why:** Při refactoru `src/components/common/Menu/Menu.ios.tsx` jsme řešili, proč se menu otevře jen po kliknutí na samotný `•••` text. Nedalo se to nakliknout všude v rámci 44×44 frame. Důvod: SwiftUI Menu používá vnitřní label view jako hit target, modifiers na vnější Menu container se na něj nepropíšou.

**How to apply:** Vždy když děláš header button / icon trigger pro `SwiftMenu` (nebo podobné `Picker`), nikdy nepoužívej string `label` s `frame`/`contentShape` modifiers a očekávání rozšířené tap area. Vždy custom JSX label.
