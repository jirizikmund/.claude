# Sjednocení barvy dostupnosti „NA CESTĚ" + commit & PR

## Context

V appce měla dostupnost **„NA CESTĚ"** šedou barvu místo žluté (rozpor s webem). Příčina: mapování
`STOCK_COLORS.on_way = 'gray52'` v `src/components/syntex/ProductDetail/utils.ts` (jediné místo, kde
se enum `skladem` mapuje na barvu; používá ho `getStockTextColor` v ProductDetail/StockInfo,
ProductPreview/ProductPreviewWide i ScreenSearch).

Opravu **už udělal uživatel sám**: `on_way: 'gray52' → 'yellow'` (barva `yellow #cfb60f` v stylekitu
existuje). Druhý reportovaný problém — **„SKLADEM U DODAVATELE" červené místo zeleného** — se
**neřeší v appce**; je to oprava na straně API (3-hodnotový enum `skladem` nerozliší „u dodavatele"
od „vyprodáno").

## Rozsah

Pouze **commit + pull request** pro již provedenou jednořádkovou změnu.

## Kroky

1. Vytvořit větev z `master` (čistý, = origin/master), např. `fix/stock-color-on-way`.
2. Commitnout **jen** `src/components/syntex/ProductDetail/utils.ts` — conventional commit, bez zmínky o Claude.
   - např. `fix(product): use yellow for "on the way" availability color`
3. Push větve + vytvořit PR (base `master`) přes `gh`, bez Claude atribuce v těle.

## Verifikace

- `git diff` PR obsahuje pouze změnu `on_way: 'gray52' → 'yellow'`.
- (Volitelně, mimo tento commit) v běžící app má produkt se `skladem = on_way` / textem „NA CESTĚ"
  žlutý text i pozadí v detailu i náhledech.
