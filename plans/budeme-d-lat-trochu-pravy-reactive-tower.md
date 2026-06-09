# Přechod na "cena bez DPH" jako jedinou pravdu v `Order.price`

## Context

Aplikace doteď v módu `priceMode = VAT_21` ukládala do `Order.price` cenu **s DPH** (total) a "bez DPH" se dopočítávala ad-hoc dělením 1.21 (jak v `Vat21SplitInputs`, tak v PDF rendereru). Klient ale chce pracovat výhradně s cenami **bez DPH** — proto se interpretace `Order.price` mění: vždy je to cena bez DPH, i v VAT_21 módu. "S DPH" se dopočítává jen v editovatelném inputu pro pohodlí uživatele.

Důsledky:
- Stávající VAT_21 objednávky musí být přepočítané (`new_price = price / 1.21`), aby nová interpretace odpovídala realitě.
- PDF přestane zobrazovat dvojici "bez DPH / s DPH" — bude tam jen uložená částka.
- Detail objednávky (UI náhled) přidá textový popisek "bez DPH" v VAT_21 módu.
- Editor v VAT_21 zachová oba inputy, ale tučný font bude jen u "bez DPH" (signalizace, co je primární).

ALL_IN zůstává beze změny.

---

## Změny po souborech

### 1. Migrační skript `scripts/migrate-vat-21.ts` (nový)

Lokálně spustitelný TS skript přes `tsx`. Workflow:

1. **Banner s upozorněním na backup**:
   ```
   ⚠️  Před spuštěním musí být provedena záloha.
       Lokální DB: postačí pg_dump / Docker volume snapshot.
       Produkční DB: spusťte v jiném terminálu `pnpm vps:backup prod`.

   Potvrzuji, že záloha proběhla a chci pokračovat? (y/N)
   ```
   Použít `@inquirer/prompts` (`confirm`) — knihovna už je v projektu (viz `scripts/setup/*`).

2. **DRY-RUN**: `prisma.order.findMany({ where: { priceMode: 'VAT_21', price: { not: null } }, select: { id, slug, orderNumber, currency, price, status } })`.
   - Vypsat tabulku (jednoduché `console.table` nebo ruční řádky):
     ```
     slug    orderNumber       cur  current (s DPH)  →  new (bez DPH)   status
     R7K2N9  20260514/001      CZK  12 100.00        →  10 000.00       confirmed
     ...
     ```
   - Spočítat celkem N záznamů. Pokud N = 0 → ukončit s informací.
   - Použít `Prisma.Decimal` pro přesné dělení: `new Decimal(price).div('1.21').toDecimalPlaces(2, Decimal.ROUND_HALF_UP)`. (Decimal je dostupný z `@prisma/client/runtime/library`.)

3. **Druhý confirm**:
   ```
   Aplikovat změny na 47 záznamů? (y/N)
   ```

4. **Apply**: `prisma.$transaction(updates)` — pole `prisma.order.update({ where: { id }, data: { price: newPrice } })` pro každý záznam. Transakce → atomicita.

5. **Výsledný výpis**: znovu vypsat tabulku s `before → after` pro každý záznam + souhrn `✨ Migrováno N záznamů.`.

6. **Audit log**: NEpsát do `AuditLog`. Migrace je systémová úprava dat, ne uživatelská akce; audit log má append-only trigger a samostatný schema `actorId`/`entityType`. Místo toho skript vypíše finální stav do stdout — uživatel si může zachytit log do souboru `... 2>&1 | tee migrate-vat-21-$(date +%s).log`.

**Spuštění (návod v komentáři skriptu):**

```bash
# Lokální DB (default DATABASE_URL z .env):
pnpm tsx scripts/migrate-vat-21.ts

# Produkční DB přes SSH tunel:
# 1) V samostatném terminálu otevři tunel:
ssh -L 5433:localhost:5432 root@<vps-ip>
# 2) V tomhle terminálu spusť skript s přepsaným DATABASE_URL:
DATABASE_URL="postgresql://boss:****@localhost:5433/boss" \
  pnpm tsx scripts/migrate-vat-21.ts 2>&1 | tee migrate-vat-21-prod.log
```

Volitelně přidat `pnpm` alias do `package.json`:
```json
"db:migrate-vat-21": "tsx scripts/migrate-vat-21.ts"
```

**Idempotence**: Skript NEpřidá flag "už migrováno". Druhé spuštění by znovu dělilo. Ochrana: skript po dotazu o backup vypíše "Tato operace je destruktivní a NENÍ idempotentní — opakované spuštění data poškodí. Pokračovat?". Klient potvrzuje. (Trvalejší ochrana není potřeba, jde o jednorázovou operaci.)

---

### 2. PDF renderer — odstranění "/ s DPH /" části

**Soubor**: `src/components/pdf/build-pdf-html.ts:49-66`

Zjednodušit `renderPriceValue()` na jeden case pro oba módy:

```ts
const renderPriceValue = () => {
  if (!order.price) return '';
  return `<strong>${formatPrice(order.price, order.currency)}</strong>`;
};
```

Smazat:
- konstantu `VAT_21_RATE` (lokální, nepoužívá se jinde v souboru)
- funkci `formatPriceNumber` (pokud ji jinde v souboru nikdo nepoužívá — ověřit `grep formatPriceNumber src/components/pdf/build-pdf-html.ts`; pokud ne, smazat)
- celý `if (order.priceMode === 'VAT_21') { ... }` blok

**PDF CSS** (pravděpodobně `src/components/pdf/pdf-styles.ts` nebo inline v build-pdf-html.ts): odstranit třídy `.price-vat-pair`, `.price-vat-suffix`, `.price-vat-sep` pokud existují a nejsou používané jinde. Bez urgence — neškodí, jen mrtvý kód.

**Legal text v PDF se nemění** — `src/lib/pdf.ts:49-62` (`getLegalText()`) je čistě text-selection podle `priceMode`, nemá vztah k ceně. Klient nadále potřebuje rozlišovat legal text per mode.

---

### 3. Detail objednávky — přidat "bez DPH" suffix v VAT_21

**Soubor**: `src/components/order/contract-price-panel.tsx:83-96` (readOnly větev)

Aktuální:
```tsx
<div className="ml-auto text-lg font-bold tabular-nums">
  {props.price ? formatPrice(Number(props.price), props.currency, locale) : '—'}
</div>
```

Nový:
```tsx
<div className="ml-auto text-lg font-bold tabular-nums">
  {props.price ? (
    <>
      {formatPrice(Number(props.price), props.currency, locale)}
      {props.priceMode === 'VAT_21' && (
        <span className="ml-2 text-xs font-normal text-muted-foreground">
          {t('priceWithoutVat')}
        </span>
      )}
    </>
  ) : (
    '—'
  )}
</div>
```

i18n klíč `priceWithoutVat` už existuje (Bez DPH / Without VAT / Ohne MwSt.) — viz `messages/cs.json` a sourozenci. ALL_IN větev je nezměněná.

Detail page `src/app/orders/[slug]/page.tsx:187-196` se nemění — předává `priceMode` do panelu, ten se postará sám.

---

### 4. Editovatelný panel — flip logiky a typografie

**Soubor**: `src/components/order/contract-price-panel.tsx`

#### 4a. JSDoc + komentáře (lines 186-194)

Aktuální komentář popisuje "Zdroj pravdy je `props.price` = S DPH". Přepsat:

```
/**
 * Pro režim VAT_21: dva inputy se vzájemnou auto-kalkulací.
 * Zdroj pravdy je `props.price` = "Bez DPH" (uložená v Order.price).
 * "S DPH" se primárně odvozuje jako `price * 1.21`, ale když uživatel
 * ručně přepíše total, jeho přesný string drží `totalOverride` — jinak
 * by se mu zaokrouhlení vrátilo zpět a vyhodilo cifry pod kurzorem.
 * Editace "Bez DPH" override resetuje.
 */
```

#### 4b. Logika `Vat21SplitInputs` (lines 195-249)

Stávající helpers `deriveBaseFromTotal` a `deriveTotalFromBase` (lines 48-58) zachovat — pojmenování je správně i pro novou semantiku (jde o matematické převody, nezávislé na tom, co je v DB).

Body to flip:
- Lokální state: přejmenovat `baseOverride` → `totalOverride`.
- `displayBase` → odstranit; přidat `displayTotal = totalOverride ?? deriveTotalFromBase(price)`.
- "Bez DPH" input (vlevo): `value={price}` (přímo z props), `onChange={handleBaseChange}`. **Toto je primární pole** — dostane `id="contractPrice"`.
- "S DPH" input (vpravo): `value={displayTotal}`, `onChange={handleTotalChange}`. **Derivované** — bez `id`.
- `handleBaseChange(value)`:
  ```ts
  setTotalOverride(null);    // reset derivace
  onPriceChange(value);      // direct → do parent (DB)
  ```
- `handleTotalChange(value)`:
  ```ts
  setTotalOverride(value);                       // drž přesný string totalu
  onPriceChange(deriveBaseFromTotal(value));     // value/1.21 → do parent (DB)
  ```

#### 4c. Typografie inputů (lines 222-247)

- **"Bez DPH" input** (label `priceWithoutVat`): zachovat `text-base font-semibold` (tučný).
- **"S DPH" input** (label `priceWithVat`): změnit `font-semibold` → `font-normal`.

Tučný font signalizuje primární / source-of-truth pole. Klient to vyžaduje explicitně.

#### 4d. Parent reference (lines 73-75)

`<label htmlFor={... props.priceMode === 'ALL_IN' ? 'contractPrice' : undefined ...}>` — v VAT_21 módu nechá `htmlFor` `undefined` (kvůli tomu, že `id="contractPrice"` dřív leželo na "s DPH" inputu uvnitř Vat21SplitInputs, a focus by skákal na nesprávné pole). Po flipnutí `id="contractPrice"` přejde na primární "bez DPH" input, takže lze label nastavit:

```tsx
htmlFor={props.readOnly ? undefined : 'contractPrice'}
```

(Funguje pro oba módy stejně — primární input má `id="contractPrice"`.)

---

## Co se NEMĚNÍ (explicitně)

- **`Order.priceMode` enum, schema, default `ALL_IN`** — přepínač zůstává funkční (uživatel vidí v editaci, legal text v PDF se podle něj vybírá).
- **i18n klíče** (`priceWithoutVat`, `priceWithVat`, `priceModeAllIn`, `priceModeVat21`, `contractPrice`) — všechny existují a jsou semanticky správné.
- **Legal text v PDF** (`src/lib/pdf.ts:49-62`) — text-only, ne cena.
- **ALL_IN flow** — žádné změny v UI ani PDF.
- **Email template** (`{price}` placeholder) — klient o emailu nemluvil. Renderuje se `formatPrice(order.price, order.currency)` (resp. text z DB šablony). Implicitně se sémantika `{price}` mění z "podle priceMode" → "vždy bez DPH". Pokud chce klient pro VAT_21 ve výchozí šabloně přidat "(bez DPH)", změní si to sám v `/admin/emails`. Žádný code change.
- **Filtr a agregace na list page** (`src/actions/orders.ts:129-137, 180-287`, `src/components/order/data-table-footer.tsx`) — SQL operuje na raw `price`. Po migraci budou hodnoty homogennější (bez DPH pro VAT_21, all-in pro ALL_IN). Žádný code change. Pokud později klient narazí na něco neintuitivního v sum/avg, řeší se samostatně.
- **PDF preview v adminu** (`/api/admin/pdf/preview`) — používá stejný `build-pdf-html.ts`, takže se chová konzistentně automaticky.

---

## Critical files

| Akce | Soubor |
|------|--------|
| NEW | `scripts/migrate-vat-21.ts` |
| MODIFY (zjednodušit `renderPriceValue`) | `src/components/pdf/build-pdf-html.ts` |
| MODIFY (readOnly suffix + flip Vat21SplitInputs + typografie) | `src/components/order/contract-price-panel.tsx` |
| MODIFY (volitelně přidat script alias) | `package.json` |

Existující funkce/utility k znovupoužití:
- `formatPrice` v `src/lib/format.ts` (PDF + UI)
- `Prisma.Decimal` z `@prisma/client/runtime/library` (migrace)
- `@inquirer/prompts.confirm` (interaktivní potvrzení v skriptu, použito v `scripts/setup/*`)
- `color()`, `info()` z `scripts/setup/ui.ts` (formátování výstupu skriptu, konzistence s `vps:backup`)
- i18n klíče `priceWithoutVat` / `priceWithVat` v `messages/{cs,en,de}.json`

---

## Verifikace (end-to-end)

### Lokálně (před prod migrací)

1. **Setup test dat**: V `/orders/new` vytvořit 2-3 objednávky v VAT_21 módu s různými hodnotami (např. 12 100 CZK, 1 815 CZK), 1-2 v ALL_IN, 1 bez ceny. Část potvrdit (`confirmed`), část nechat `draft`.
2. **Dry-run skriptu**: `pnpm tsx scripts/migrate-vat-21.ts` → odmítnout first confirm → ověřit, že skript ukončí bez změn. Spustit znovu → potvrdit backup → ověřit, že DRY-RUN vypíše VAT_21 záznamy s `current → new` a NECHCE nic měnit dokud nepotvrdím apply. Odmítnout second confirm → ověřit, že DB je beze změn (Prisma Studio).
3. **Apply**: Pustit skript znovu, potvrdit obě výzvy. Ověřit:
   - Decimal přesnost: `12100.00 / 1.21 = 10000.00` exact, žádný drift.
   - Záznamy bez ceny netoknuté.
   - ALL_IN záznamy netoknuté.
4. **UI detail** (`/orders/<slug>`): otevřít migrovanou VAT_21 objednávku → ContractPricePanel ukáže novou cenu + suffix "Bez DPH". ALL_IN beze suffixu.
5. **UI edit** (`/orders/<slug>/edit`): otevřít VAT_21 → "Bez DPH" je tučně, "S DPH" je normálním fontem. Editace "Bez DPH" → "S DPH" se přepočítá živě. Editace "S DPH" → "Bez DPH" se přepočítá. Submit → znovu otevřít → hodnoty sedí.
6. **PDF stažení**: pro VAT_21 i ALL_IN potvrzenou objednávku stáhnout PDF → ověřit, že je tam jen jedna částka v tučném (žádný "/ s DPH /"), legal text se stále vybírá per mode.
7. **`pnpm typecheck && pnpm lint`**.

### Produkce

1. `pnpm vps:backup prod` (manuálně, klient potvrdí v terminálu).
2. SSH tunel: `ssh -L 5433:localhost:5432 root@<vps-ip>`.
3. `DATABASE_URL="<prod-url-přes-localhost:5433>" pnpm tsx scripts/migrate-vat-21.ts 2>&1 | tee migrate-vat-21-prod.log`.
4. Smoke-test: otevřít náhodnou potvrzenou VAT_21 objednávku v UI + stáhnout PDF → ověřit hodnoty.

---

## Pořadí implementace (commits)

1. `feat(orders): store price excluding VAT, migration script for VAT_21 orders`
   — Nový `scripts/migrate-vat-21.ts` + (volitelně) `pnpm db:migrate-vat-21` alias.
2. `refactor(pdf): render single price value (without VAT semantics)`
   — Změna `build-pdf-html.ts`, smazání dead VAT-pair HTML/CSS.
3. `feat(orders): flip Vat21 inputs to use price-without-VAT as source of truth`
   — `contract-price-panel.tsx` — logika + typografie + readOnly suffix.

(Migrace musí proběhnout lokálně **před** zapnutím nové logiky v UI/PDF na produkci — jinak by se uložené "s DPH" ceny zobrazovaly jako "bez DPH". V deploy pipeline: build commitnout, deploy zastavit; nejdřív backup + migrate-vat-21 na prod, pak deploy nové verze.)
