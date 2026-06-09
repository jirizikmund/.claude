# Slug objednávky 5 → 6 znaků

## Context

Uživatel chce rozšířit URL slug objednávky z 5 na 6 znaků a ptá se, jestli to bude problém. **Krátká odpověď: ne, je to triviální (~5 minut). Žádná migrace, žádný breaking change, staré URL pořád fungují.**

## Proč to není problém

- DB schema (`prisma/schema.prisma`): `slug String @unique` — TEXT bez `@db.VarChar(N)` constraint. PostgreSQL TEXT pojme libovolnou délku.
- `normalizeSlug()` v `src/lib/slug.ts` neměří délku, jen `trim().toUpperCase()`.
- Žádné Zod schema neválicuje `slug.length === 5`.
- Next.js `[slug]` segment v routingu žere libovolnou délku.
- Staré 5-char slugy v DB **zůstávají** plně funkční — jen nově generované budou 6-znakové. URL `/orders/R7K2N` (existující) pořád funguje vedle `/orders/A2K7M9` (nové).
- Collision space: dnes `33^5 = 39 mil.` → `33^6 = 1,29 mld.` kombinací. Retry-on-collision logika (`generateUniqueSlug` v `src/actions/orders.ts`, max 10 pokusů) zůstává s gigantickou rezervou.

## Konkrétní změny

**Povinná (1 znak):**
- `src/lib/slug.ts:9` — `const SLUG_LENGTH = 5;` → `const SLUG_LENGTH = 6;`

**Cleanup (cosmetic, 2 místa):**
- `src/app/admin/emails/email-preview-modal.tsx:33,35` — sample placeholder `orderNumber: 'R7K2N'` → `'R7K2N9'` (6 chars). Jen estetická konzistence v admin náhledu — neovlivňuje funkci.
- `CLAUDE.md` v sekci „Implementační detaily" — zmínka „Order slug: 5-char alphanumeric ... URL: `/orders/R7K2N/edit`" → změnit na 6-char + příklad.

## Co NENÍ potřeba

- ❌ DB migrace — schema nemá length constraint.
- ❌ Backfill / přepis existujících slugů — staré 5-char zůstávají.
- ❌ URL redirect compatibility layer — staré URL fungují dál.

## Kritické soubory

- `src/lib/slug.ts` — generátor (1 řádek)
- `src/app/admin/emails/email-preview-modal.tsx` — sample data v náhledu (kosmetické)
- `CLAUDE.md` — projektová dokumentace

## Verifikace

1. `pnpm typecheck` — projde, nezměnili jsme typy.
2. `pnpm dev` → vytvořit nový koncept → URL bude `/orders/XXXXXX/edit` (6 znaků), v hlavičce konceptu se zobrazí 6-char tag.
3. Otevřít existující 5-char objednávku (např. dříve vytvořený `R7K2N`) → musí dál fungovat.
4. Náhled e-mailu v `/admin/emails` → placeholder `{orderNumber}` zobrazí novou 6-char hodnotu.
