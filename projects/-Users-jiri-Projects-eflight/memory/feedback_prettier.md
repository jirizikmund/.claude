---
name: Prettier formatting
description: Vždy respektovat prettier konfiguraci projektu při úpravách kódu
type: feedback
---

Při úpravách kódu VŽDY respektovat prettier konfiguraci projektu (.prettierrc.json).

Klíčová pravidla:
- `tabWidth: 4`, `useTabs: false` — odsazení 4 mezery
- `singleQuote: true` — jednoduché uvozovky
- `trailingComma: "es5"` — trailing čárky v ES5 kontextech
- `printWidth: 120` — maximální délka řádku 120 znaků
- `semi: true` — středníky na konci
- `bracketSpacing: true` — mezery v objektových literálech `{ foo }`
- `arrowParens: "always"` — závorky kolem single parametru arrow funkcí `(x) =>`

**Why:** Uživatel upozornil, že moje úpravy nerespektovaly prettier — vznikal nekonzistentní kód.

**How to apply:** Při každém zápisu nebo editaci kódu v tomto projektu se řídit těmito pravidly. Před commitem VŽDY spustit `npx prettier --write` na všechny upravené TS/TSX/JS soubory. SASS soubory prettier nepodporuje.
