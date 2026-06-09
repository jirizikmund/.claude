# 8 úprav order systému (BOSS)

## Context

Sada osmi nezávislých úprav v BOSS:
- doplnění chybějícího "Save as new customer" na položce objednávky,
- oprava nesouladu mezi globální konfigurací povinnosti polí a UI (truckPlate/crew),
- dvě nové informativní sloupce v tabulce objednávek + sticky actions sloupec + přepínač "Plná šířka",
- sjednocení formuláře kontaktu mezi adminem (Dopravci/Zákazníci) a editací objednávky,
- nový cenový režim "21 % DPH" vedle stávajícího "All IN" + jeho promítnutí do PDF (per-režim právní text pod cenou).

Cílem je dodržet inkrementální rytmus — **každý úkol = vlastní commit**.

---

## Úkol 1: "Uložit jako nového zákazníka" na položce objednávky

**Stav:** `OrderItemForm` má prop `onSaveCustomer` a interní handler `handleSaveCustomer` (`order-item-form.tsx:35-45, 164-178, 330-332`) — UI tlačítko přes `ContactEditor` se zapíná podle `canSaveAsNew={isNewCustomer && !!onSaveCustomer}`. Chybí jen propojení v rodičovské komponentě `OrderForm`.

**Vzor:** Plně funkční flow pro dopravce v `order-form.tsx:263-312` (`saveCarrierAsContact`) — s detekcí duplicit přes IČO (`lookupCarrierByIco`) a confirm dialogem.

**Implementace:**

1. `src/actions/customers.ts` — přidat `lookupCustomerByIco(ico: string)` analogicky k `lookupCarrierByIco` v `src/actions/carriers.ts`.
2. `src/components/order/order-form.tsx`:
   - V parent komponentě, kde se renderuje `OrderItemForm`, dodat callback `handleSaveCustomerFromItem` (mirror existing `saveCarrierAsContact`):
     - Volá `lookupCustomerByIco`
     - Při duplicit IČO → `useConfirm` dialog (Uložit jako nový / Aktualizovat stávající)
     - Volá `createCustomer` nebo `updateCustomer`
     - Aktualizuje `customerContacts` state (přidá nový záznam)
     - Vrátí `{ id }` (parent komponenta `OrderItemForm` napojí `customerContactId`)
   - Předat callback jako `onSaveCustomer` propou do každého `<OrderItemForm>` instance.
3. i18n texty `saveCustomer`, `saveAsNewContact` už existují v `messages/cs.json` / `en.json` / `de.json` (používá je dopravce). Zkontrolovat a případně doplnit.

**Commit:** `feat(orders): add "save as new customer" on order item`

---

## Úkol 2: SPZ tahač + Osádka defaultně nepovinné

**Stav:** `src/config/field-requirements.ts` má hardcoded `truckPlate: { required: true }` a `crew: { required: true }`. UI i potvrzovací validace jdou podle této konfigurace.

**Implementace:**

1. `src/config/field-requirements.ts`:
   - `truckPlate: { required: true }` → `{ required: false }`
   - `crew: { required: true }` → `{ required: false }`

Admin per-entity overrides (přes `FieldValidationConfig` DB tabulku) zůstávají funkční — pokud admin nastaví explicitně required, projeví se to.

**Commit:** `fix(field-requirements): default truckPlate and crew to optional`

---

## Úkol 3: Nové sloupce "Zákazník" a "Místo"

**Stav:** `getOrders()` v `src/actions/orders.ts:520-535` načítá `items: { orderBy: { sortOrder: 'asc' }, select: { date: true } }`. Sloupce definované v `src/components/order/data-table-columns.tsx:44-230`.

**Implementace:**

1. `src/actions/orders.ts`:
   - V `includeShape` rozšířit `items.select`: `{ date: true, companyName: true, city: true, sortOrder: true }`
   - Typ `OrderRow` (kdekoli definován) rozšířit o `items[0].companyName`, `items[0].city`.
2. `src/components/order/data-table-columns.tsx`:
   - Dva nové sloupce po `firstItemDate`:
     - `customerCompanyName` — `items[0]?.companyName ?? '—'`
     - `customerCity` — `items[0]?.city ?? '—'`
   - Default visibility: `true` (volitelné přes column settings)
   - Sortovatelnost: ne (vyžadovalo by JOIN řazení v Prisma queries — mimo scope)
3. `messages/cs.json`, `en.json`, `de.json` — přidat klíče `orders.customer`, `orders.customerCity` (nebo `place`).

**Commit:** `feat(orders): add customer and place columns to orders table`

---

## Úkol 4: Sticky poslední sloupec (actions menu + nastavení)

**Stav:** Tabulka `<table>` v `src/components/order/data-table.tsx:268-396`. Žádný sloupec není sticky-right; horizontální scroll je už podporovaný (`overflow-x-auto`).

**Implementace:**

1. `data-table-columns.tsx` — actions sloupec (poslední) dostane className na `<th>` i `<td>`:
   - `sticky right-0 z-10 bg-background` (header)
   - `sticky right-0 z-10 bg-background` (cell)
   - Subtilní separator: `shadow-[-2px_0_4px_rgba(0,0,0,0.04)]` nebo `border-l border-border/40` pro vizuální oddělení během horizontálního scrollu
2. Hover styl řádku — sticky cell potřebuje vlastní hover bg, jinak by zůstal pozadí stejné jako default. Použít `group-hover:bg-accent` (řádek `<tr>` má `group` class).
3. Header sticky: aktuálně `TableHeader` má `sticky top-0`; tam musí poslední `<th>` mít `right-0` + vyšší z-index než thead (kvůli křížení).

**Commit:** `feat(orders): pin last actions column to right edge`

---

## Úkol 5: Toggle "Plná šířka"

**Stav:** Layout v `src/app/orders/page.tsx:73-100`:
```tsx
<main className="mx-auto flex w-full max-w-7xl flex-1 flex-col overflow-hidden px-4 py-4">
  <DataTable ... />
</main>
```
Persistence sloupců (`ordersColumns`) řešená přes `UserPreferences` model + `updateOrdersColumns()` server action.

**Implementace:**

1. **DB:** Přidat sloupec `ordersFullWidth: Boolean @default(false)` do `UserPreferences` (`prisma/schema.prisma`).
   - Migrace: `pnpm prisma migrate dev --name add_orders_full_width`
2. **Server action:** `src/actions/user-preferences.ts` — přidat `updateOrdersFullWidth(value: boolean)` (mirror existing `updateOrdersColumns`).
3. **Layout změna:** `src/app/orders/page.tsx` — načíst `fullWidth` z preferences a předat do `<DataTable>`. Layout přepínat:
   - `<main>` zůstane jako wrapper s padding/flex, ale **nemá max-width constraint**.
   - Toolbar (`DataTableToolbar`) a Pagination (`DataTablePagination`) obalit do `<div className="mx-auto w-full max-w-7xl">`.
   - Tabulkový container (`relative flex-1 ...`) — když `fullWidth`, žádné max-width; když ne, `mx-auto max-w-7xl`.
4. **DataTable settings menu:** `data-table.tsx:286-342` — nad/pod stávající column visibility list přidat `<DropdownMenuCheckboxItem>` pro toggle. Při změně volat debounced `updateOrdersFullWidth` (stejný debounce mechanismus jako pro columns).
5. **i18n:** klíč `orders.fullWidth` (Plná šířka / Full width / Volle Breite).

**Commit:** `feat(orders): add full-width table toggle`

---

## Úkol 6: Admin modal Dopravci/Zákazníci → reuse `ContactEditor`

**Stav:** Skutečně používaný flow:
- `/carriers/page.tsx` → `ContactTable` (`src/components/contacts/contact-table.tsx`) → `ContactModal` (`src/components/contacts/contact-modal.tsx`).
- `/customers/page.tsx` (analogicky) → `ContactTable` → `ContactModal`.
- Stejný `ContactModal` v hlavní pagině pro Dopravci i Zákazníci (rozdíl je jen v translation namespace + onSave handler).
- `CarrierModal` z `src/app/carriers/carrier-modal.tsx` (s ralCode/timocomCode/paymentTermsDays) v aktuálním routě **není napojený** — viz screenshot.

`ContactEditor` (`src/components/ui/contact-editor.tsx`) je přesně ta cílová komponenta — již použitá v order edit pro dopravce i zákazníka. Selektor (`options`) je optional a nezobrazí se, pokud není předán; ARES je defaultně zapnutý.

**Implementace:**

1. `src/components/contacts/contact-modal.tsx` — formulář vyměnit za `ContactEditor`:
   - State pro contact data (companyName, street, zip, city, country, ico, dic, phone, email).
   - `<ContactEditor>` bez `options` (žádný selector).
   - `showAres={true}` (admin si může načíst data z ARES jako dosud).
   - `onAresApplied={...}` → naplní state.
   - `onFieldChange={...}` → aktualizuje state.
   - Buttons "Zrušit / Uložit" a 3-tečky menu s "Smazat" zůstanou v hostujícím modal layoutu.
2. `src/app/carriers/carrier-modal.tsx` — odebrat (orphaned, pokud confirm grep ukáže, že ho nikde nepoužíváme reálně). Pokud `carrier-table.tsx` a `carrier-list.tsx` taky nejsou napojené, odebrat i ty.
   - **Ověření před delete:** `rg -l "from '\\./carrier-list'|from '\\./carrier-modal'|from '\\./carrier-table'" src/`. Pokud nikdo nezpoužívá, smazat.
3. `messages/{cs,en,de}.json` — `carriers.editContact` / `customers.editContact` titulky nech beze změny (`ContactModal` už translation namespace má).

**Commit:** `refactor(contacts): admin modals reuse ContactEditor`

---

## Úkol 7: Cenové režimy — `ALL_IN` + `VAT_21`

**Stav:** `Order.price: Decimal? @db.Decimal(12, 2)` (`prisma/schema.prisma:207`). UI: `ContractPricePanel` (`src/components/order/contract-price-panel.tsx`) — jeden input + přepínač měny. Žádný cenový režim neexistuje.

**Implementace:**

1. **DB schema:**
   - `prisma/schema.prisma`: nový enum `PriceMode { ALL_IN VAT_21 }` + sloupec `priceMode PriceMode @default(ALL_IN)` na `Order`.
   - Migrace: `pnpm prisma migrate dev --name add_price_mode`. Existující objednávky → `ALL_IN` (default).
2. **Zod schemas:**
   - `src/schemas/order.ts`: přidat `priceMode: z.enum(['ALL_IN', 'VAT_21']).default('ALL_IN')` do `orderFormSchema`.
3. **UI — `ContractPricePanel`:**
   - Segment control / button group **nahoře** uvnitř panelu: [ALL IN] [21 % DPH] (i18n texty `orders.priceModeAllIn`, `orders.priceModeVat21`).
   - **Edit mode:**
     - `ALL_IN`: jeden `PriceInput` (chování jako dnes) — pole `price`.
     - `VAT_21`: dva `PriceInput`y (vedle sebe nebo pod sebou):
       - "Bez DPH" (basePrice) — interní state, ne v DB
       - "S DPH" (price) — perzistentní v `Order.price`
       - Při editaci jednoho se druhý přepočítá: `withVat = base * 1.21`, `base = withVat / 1.21` (zaokrouhlení na 2 des. místa).
       - Při přepnutí režimu: hodnota `Order.price` zachována (cena = vždy "konečná").
   - **Read-only mode:** zobrazit cenu + při `VAT_21` doplnit "(z toho bez DPH: X)" pod ní. Volitelné — pokud nepatří do scope, vynechat (uživatel toto nepožadoval explicitně).
4. **PDF:** Pole `price` v PDF zobrazí přesně tu samou hodnotu jako dnes (cena s DPH ↔ all-in cena, podle režimu). Volitelné: u `VAT_21` doplnit i bez DPH — opět **mimo scope**, dokud uživatel nepožádá.

**Commit:** `feat(orders): add VAT_21 price mode with auto-calculated base/total`

---

## Úkol 8: PDF admin — právní text per cenový režim

**Stav:** `pdf.legalText` v `SystemConfig` je JSON `{cs, en, de}` (`src/actions/pdf-config.ts:50-72`). Sanitizace přes `sanitize-html`. Renderuje se v `src/components/pdf/build-pdf-html.ts:181, 225` jako `${legalTextHtml}` pod cenovým boxem.

**Implementace:**

1. **DB struktura:** Změnit JSON value pro `pdf.legalText` na `{ ALL_IN: {cs, en, de}, VAT_21: {cs, en, de} }`.
   - **Backfill:** Jednorázový migrace skript (nebo seed step) — současný `{cs, en, de}` namapovat do obou módů (ALL_IN i VAT_21 dostanou stejný startovní text). Nový schema bude takto strukturovaný od začátku.
   - Implementace: rozšířit `loadPdfConfig` / `updatePdfConfig` v `src/actions/pdf-config.ts` o nový shape. Backfill provést při prvním read (lazy migration) nebo přidat do `db:seed` skriptu.
2. **Schema:** `src/schemas/pdf-config.ts` — `legalText` typ změnit z `{cs, en, de}` na `{ ALL_IN: {cs, en, de}, VAT_21: {cs, en, de} }`.
3. **Admin UI:** `src/app/admin/pdf/pdf-config-form.tsx`:
   - Nad RichTextEditor pro "Právní text pod cenou" přidat **stejný segment control** jako v `ContractPricePanel` (`ALL IN | 21 % DPH`). Jednoznačně signalizuje souvislost.
   - Editor se po přepnutí přepojí na druhou hodnotu (státní state s diff trackingem).
   - Při ukládání se uloží oba texty (per-jazyk + per-režim).
4. **PDF rendering:** `src/components/pdf/build-pdf-html.ts`:
   - `loadPdfConfig()` vrací oba texty.
   - Při generování: `legalTextHtml = config.legalText[order.priceMode][lang] ?? ''`.
5. **Audit log:** mě se ukládáním legalText (existing audit) zachovat — log entry obsahuje který režim/jazyk byl změněn.

**Commit:** `feat(pdf-config): per-price-mode legal text under price`

---

## Kritické soubory

| Úkol | Klíčové soubory |
|------|-----------------|
| 1 | `src/components/order/order-form.tsx`, `src/components/order/order-item-form.tsx`, `src/actions/customers.ts` |
| 2 | `src/config/field-requirements.ts` |
| 3 | `src/actions/orders.ts`, `src/components/order/data-table-columns.tsx`, `messages/*.json` |
| 4 | `src/components/order/data-table-columns.tsx`, `src/components/order/data-table.tsx` |
| 5 | `prisma/schema.prisma`, `src/actions/user-preferences.ts`, `src/app/orders/page.tsx`, `src/components/order/data-table.tsx` |
| 6 | `src/components/contacts/contact-modal.tsx`, případně delete `src/app/carriers/{carrier-modal,carrier-table,carrier-list}.tsx` (po ověření) |
| 7 | `prisma/schema.prisma`, `src/schemas/order.ts`, `src/components/order/contract-price-panel.tsx`, `messages/*.json` |
| 8 | `prisma/schema.prisma` (žádná změna), `src/actions/pdf-config.ts`, `src/schemas/pdf-config.ts`, `src/app/admin/pdf/pdf-config-form.tsx`, `src/components/pdf/build-pdf-html.ts` |

## Reuse existujících komponent / utilit

- `ContactEditor` (`src/components/ui/contact-editor.tsx`) — universální (selector optional, ARES toggle).
- `lookupCarrierByIco` (`src/actions/carriers.ts`) — vzor pro `lookupCustomerByIco`.
- `saveCarrierAsContact` flow v `order-form.tsx:263-312` — vzor pro `handleSaveCustomerFromItem`.
- `useConfirm` (`src/components/ui/confirm-dialog`) — pro duplicate dialog.
- `updateOrdersColumns` (`src/actions/user-preferences.ts`) — vzor pro `updateOrdersFullWidth`.
- `fieldRequirements` (`src/config/field-requirements.ts`) — centralizovaný config pro povinnost polí.

## Migrace DB

Před commitem schema změn:
- `pnpm prisma migrate dev --name add_orders_full_width` (úkol 5)
- `pnpm prisma migrate dev --name add_price_mode` (úkol 7)

Pro lokální dev se použije `pnpm db:push`. Produkční deploy je `prisma migrate deploy` v `deploy.sh`.

## Verification

Pro každý commit:
1. `pnpm typecheck`
2. `pnpm lint`
3. `pnpm dev` → spustit appku, manuálně otestovat příslušnou feature:
   - Úkol 1: na nové objednávce přidat položku, vyplnit data zákazníka, ověřit zda se objeví "Uložit jako nového zákazníka"; uložit; ověřit v `/customers` že tam je.
   - Úkol 2: nová objednávka — na dopravci ověřit, že truckPlate/crew nejsou označeny hvězdičkou; potvrdit objednávku — neblokuje to.
   - Úkol 3: tabulka objednávek zobrazí nové sloupce; mají správná data (nakl/vykl města a názvy zákazníků).
   - Úkol 4: horizontální scroll tabulky → actions sloupec zůstane vpravo; settings dropdown stále funguje.
   - Úkol 5: zapnout "Plná šířka" → tabulka zabere celé okno, toolbar/pagination ne; přepnutí persistuje po reloadu.
   - Úkol 6: `/carriers` → editovat → modal vypadá jako contact editor v objednávce; ARES funguje. Stejně pro `/customers`.
   - Úkol 7: cenový režim VAT_21 → dva inputy, vzájemný auto-calc; ALL_IN → jeden input; přepnutí mezi režimy zachová cenu.
   - Úkol 8: admin/pdf → přepínač režimu nad legalText editorem; každý režim má vlastní text per-jazyk; objednávka v ALL_IN dostane ALL_IN text v PDF, VAT_21 dostane VAT_21 text.

## Out of scope (záměrně)

- Sortovatelnost nových sloupců "Zákazník"/"Místo" v DB query (vyžadovalo by JOIN řazení).
- Doplňující zobrazení "z toho bez DPH" v PDF u režimu VAT_21 — uživatel nepožadoval.
- Doplňování chybějících admin polí (ralCode, timocomCode, paymentTermsDays) do live UI — uživatel nepožadoval, mimo scope. Schema je v DB, jen UI je nepoužívá.
