---
name: Barvy — sémantické přes useColors, žádné raw hex
description: V mFTL používat výhradně sémantické barvy přes useColors hook; Figma JSON je source of truth pro tokeny
type: feedback
originSessionId: e36aacaa-c108-4340-b116-23898ccd1eef
---
V mFTL aplikaci platí **strict pravidlo pro barvy**:

1. **Pouze přes `useColors()`** — žádný raw hex (`#FFFFFF`), žádný `Colors_old.*`, žádný direct `COLORS.*` v komponentě.
2. **Sémantické tokeny** — `Colors.bg.surface`, `Colors.text.primary`, `Colors.action.primary`, atd. (definované v `src/constants/Colors.ts`).
3. **Source of truth pro mapování** — Figma JSON exporty:
   - `/Users/jiri/Downloads/primitives.json` (primitivy: grey-100..900, blue-400/500/600, atd.)
   - `/Users/jiri/Downloads/Semantic/Light.semantic.json` (light mode mapování)
   - `/Users/jiri/Downloads/Semantic/Dark.semantic.json` (dark mode mapování)

**Why:** Bez striktní konvence se tokeny rozjedou s Figmou — barvy v kódu nejsou aktualizovatelné spolu s designem, vznikají magic hex, dark/light theme se rozjedou.

**How to apply:**
- Když v kódu narazím na `'#XXXXXX'` v komponentě (mimo `Colors.ts`), `LicensePlate.tsx` (real-world barvy) nebo shadow utility (`useBoxShadows.ts`), je to bug k opravě → najít odpovídající sémantický token v Colors.ts.
- Pokud sémantický token chybí, prověřit Figma JSON, případně přidat do `src/constants/Colors.ts`.
- Při auditu redesignovaného souboru: žádný `useColors_old`/`Colors_old.*` nesmí zůstat. Pokud nativní RN komponenta vyžaduje barvy (např. `Switch trackColor`), použít sémantické (např. `Colors.divider`/`Colors.action.primary`).
- Pro RN-native interní komponenty s univerzálními barvami (modal backdrop = `COLORS.black`) je akceptovatelné direct `COLORS.*`.

**Pre-existující odchylky (k zafixování v rnkit, ne v projektu):**
- rnkit `COLORS.blue400` = `#48A2F4`, ale Figma `blue-400` = `#4BA2F4` (drobně odlišné, sub-perceptible)
- rnkit `COLORS.purple300` = `#A9A8C1`, ale Figma `purple-300` = `#A9ABC1` (drobně odlišné)
- Až bude rnkit aktualizovaný, zmizí to automaticky.
