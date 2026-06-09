---
name: Redesign mFTL — série tasků
description: Aktivní redesign mFTL aplikace probíhá v sérii TMS tasků; používá nové design tokeny + komponenty, staré se postupně nahrazují
type: project
originSessionId: e36aacaa-c108-4340-b116-23898ccd1eef
---
Redesign aplikace mFTL probíhá v sérii ClickUp tasků (custom ID TMS-XXX):

- **TMS-522** — Foundation: nový `Colors` objekt + `useColors` hook (`src/hooks/useColors.ts`, `src/constants/Colors.ts`), nový `Button` komponent (`src/components/common/buttons/Button.tsx`), `TabSwitch`, `List`/`ListItem`, `ScreenComponentShowcase` (dev-only playground)
- **TMS-536** — Auth obrazovky: redesign Login, Register, IntroScreen, PasswordGate, nový `TextInput` (`src/components/common/TextInput.tsx`)
- **TMS-538** — NativeTabs (expo-router) místo custom bottom tabs (`src/app/(tabs)/_layout.tsx`)
- **TMS-539** — Settings sekce: Settings, Language, ColorTheme, LocationServices, FontSize obrazovky + native iOS large title pattern
- **TMS-556** — Záložka Podpora: nový `DispatcherCard` panel místo zelených `SuccessButton`. PhoneDial zachován. Sekce „Přednastavené kontakty" + tlačítka „Přidat/Editovat" zatím out of scope.

**Why:** Postupný přechod ze starého design systému na nový (DM Sans typography, dark-mode tokeny, tmavé panel layouty) podle Figma souborů mFTL-DEV / mFTL-app.

**How to apply:**
- Nové redesignované screeny: `useColors` (ne `useColors_old`), tokeny `Colors.bg.surface/.icon/.base`, `Colors.text.primary/.support`, `Colors.border/.divider`
- Fonty: `BODY_400/500/700`, `SUBTITLE_400/500/700`, `TITLE_400/500/700` (DM Sans, size 16/20/24)
- Komponenty: nový `Button` (variants primary/secondary/textPrimary/...), `List`+`ListItem` pro nastavení, `DispatcherCard` pro dispečerské kontakty, `TabSwitch` pro segment switcher
- Staré komponenty k nahrazení: `useColors_old`, `SuccessButton`/`PrimaryButton`/`DangerButton` (variants `ButtonVariant`), `MtmsTextInput`, `Colors_old.*` tokeny
- Při dotazu na další task v sérii (TMS-557+) předpokládat, že navazuje a používat nové komponenty/tokeny
