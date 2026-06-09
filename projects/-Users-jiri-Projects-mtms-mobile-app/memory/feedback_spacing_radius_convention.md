---
name: SPACING/RADIUS coef = Figma token název
description: V mFTL používat SPACING(N)/RADIUS(N) přesně podle Figma názvu tokenu, ne podle pixelové hodnoty
type: feedback
originSessionId: e36aacaa-c108-4340-b116-23898ccd1eef
---
V mFTL aplikaci platí 1:1 mapování mezi Figma tokeny a rnkit hooky:

- Figma `spacing-N` → `SPACING(N)` (např. Figma `spacing-4` = `SPACING(4)` = 16px)
- Figma `radius-N` → `RADIUS(N)` (např. Figma `radius-3` = `RADIUS(3)` = 12px)

Aktuální hodnoty v rnkit (po updatu):
- `SPACING(1..6)` = `[4, 8, 12, 16, 20, 24]` px (linearní s Figmou)
- `SPACING(7..12)` = `[32, 40, 56, 64, 72, 80]` (větší skoky pro layout)
- `RADIUS(1..7)` = `[4, 8, 12, 16, 20, 24, 32]` px

**Why:** Předchozí verze rnkit měla nelineární SPACING (skip 12 mezi 8 a 16), takže Figma `spacing-4` (16px) musel být `SPACING(3)`. Po updatu rnkit je škála lineární — uživatel chce, aby kód „mluvil" stejným jazykem jako Figma, takže `spacing-N` v designu → `SPACING(N)` v kódu, žádné mentální překládání.

**How to apply:**
- Při čtení Figma specs vždy zapisovat coef přímo (`SPACING(4)`, ne `SPACING(3)`)
- Pokud Figma má `radius-N`, použít `RADIUS(N)` (ne raw px, ne `borderRadius={12}`)
- Pokud Figma má raw px hodnotu, která neodpovídá žádnému rnkit tokenu (např. 6px), **upozornit uživatele** — buď přidat token do rnkit, nebo akceptovat raw hodnotu vědomě
- Pixelové hodnoty bez Figma tokenu (např. `gap-[12px]` v Figmě) lze stále použít přes nejbližší SPACING coef (12 = SPACING(3)) — pokud sedí, používat hook
- Při auditu existujícího kódu mít na paměti, že staré hodnoty `SPACING(3)` mohly být = 16 (před rnkit updatem); nyní jsou 12 — mohou být v projektu off-by-one
