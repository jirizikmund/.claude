# Grafický upgrade bloků - procedurální textury + auto-tiling

## Context

Bloky jsou momentálně jednobarevné obdélníky s 1px mezerou. Potřebujeme:
1. Materiály vypadají realisticky (hlína, kámen, diamant, skála)
2. Sousední bloky stejného typu jsou vizuálně propojené (žádné mezery)

## Přístup

### 1. Procedurální textury (`src/utils/textures.ts`)

Nový soubor. Funkce `generateBlockTextures(scene)` volaná z BootScene.
Pro každý materiál vygeneruje 4 varianty textur (CELL_SIZE × CELL_SIZE) pomocí Phaser Graphics API:

- **Dirt**: Hnědý základ + náhodné tmavší/světlejší tečky (zrnka hlíny), drobné kořínky
- **Stone**: Šedý základ + trhliny (tenké linie), mírná barevná variace (světlejší/tmavší fleky)
- **Diamond**: Tmavě modrý/teal základ + jasné krystalické linie, třpytivé body
- **Rock**: Velmi tmavě šedý, drsná textura, hustší vzor, horizontální žilky

Textury jsou tile-able (bezešvé) - detaily nekončí na hraně buňky.
Klíče textur: `dirt_0`, `dirt_1`, ..., `rock_3`

### 2. Úprava Block (`src/objects/Block.ts`)

- Změna z `Rectangle` na `Image` s vygenerovanou texturou
- Plný CELL_SIZE (bez -1 mezery) → sousední bloky se dotýkají
- Varianta textury vybrána pozicí: `${type}_${(col * 7 + row * 13) % 4}` (deterministický pseudonáhodný výběr)
- Damage: tint do tmavšího odstínu místo alpha

### 3. Hrany mezi různými materiály (`src/objects/Block.ts`)

Každý blok má volitelné tenké okraje (1-2px) na stranách sousedících s jiným typem:
- Metoda `updateEdges(grid: Grid)` kontroluje 4 sousedy
- Pokud soused je jiný typ (nebo neexistuje/AIR): nakreslí tenkou tmavou linii na té straně
- Implementace: Graphics objekt jako child v Block (nebo přímo v konstruktoru)

### 4. Volání updateEdges z Grid

Po vygenerování nového řádku zavolat `updateEdges` na bloky v novém řádku a řádku nad ním (protože nový řádek je spodní soused).

## Soubory k úpravě

1. **`src/utils/textures.ts`** (nový) - generování textur
2. **`src/objects/Block.ts`** - Rectangle → Image, textury, edges
3. **`src/objects/Grid.ts`** - volání updateEdges po generování řádku
4. **`src/scenes/BootScene.ts`** - volání generateBlockTextures()
5. **`src/config.ts`** - přidání variant count konstanty

## Ověření

- `pnpm dev` → vizuální kontrola v prohlížeči
- Bloky stejného typu vypadají propojené
- Každý materiál má odlišnou vizuální identitu
- Hrany mezi různými materiály jsou viditelné
- Damage stále vizuálně funguje
