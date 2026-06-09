# Admin → PDF (fáze 5.4 — texty + smluvní podmínky + filename template + náhled)

## Kontext

V `docs/implementation-plan.md` je fáze 5.4 ("Konfigurace PDF textů v adminu") evidovaná jako **odložená** (CLAUDE.md, `memory/project_implementation_state.md`). Klient Plzeňského Prazdroje chce přes admin UI editovat statické texty na PDF "Smlouva o přepravě věcí" bez deploymentu — analogicky tomu, jak už v adminu edituje email šablonu (sekce E-maily).

V `src/lib/pdf.ts:120` je TODO comment:

```ts
appendixItems: [], // TODO: load from config when admin UI is ready
```

Tedy `appendixItems` (= smluvní podmínky na poslední straně PDF) jsou jediný text který se v PDF momentálně **nezobrazuje** — load z `SystemConfig` se nikdy neaktivoval, protože UI pro jejich editaci nikdy nebyl. Operátor je explicitně zmínil ("smluvní podmínky které jsou vždy na poslední straně"), takže tahle díra musí být zacelena.

Ostatních 7 textů (title, subtitle1, subtitle2, legalText, appendixTitle, appendixHeading, footer) je už ukládáno v `SystemConfig` rows s klíči `pdf.*`, value `{cs, en, de}`. Aktuálně se mění jen přes `prisma/seed.ts` nebo přímý SQL — admin UI pro ně neexistuje.

**Scope (potvrzeno):** texty + smluvní podmínky (jako rich text HTML) + šablona názvu PDF souboru + náhledové tlačítko které vygeneruje ukázkové PDF. **Logo upload je explicitně mimo scope** — odloženo na později.

## Cílový stav

| Pole v adminu | Storage klíč v `SystemConfig` | Typ value |
|---|---|---|
| Title (nadpis dokumentu) | `pdf.title` | `{cs, en, de}` (string) |
| Subtitle 1 | `pdf.subtitle1` | `{cs, en, de}` (string) |
| Subtitle 2 | `pdf.subtitle2` | `{cs, en, de}` (string) |
| Právní text pod cenou | `pdf.legalText` | `{cs, en, de}` (string) |
| Nadpis poslední strany | `pdf.appendixTitle` | `{cs, en, de}` (string) |
| Nadpis seznamu podmínek | `pdf.appendixHeading` | `{cs, en, de}` (string) |
| **Smluvní podmínky (rich text)** | `pdf.terms` (NOVÝ) | `{cs, en, de}` (HTML string) |
| Footer | `pdf.footer` | `{cs, en, de}` (string) |
| **Šablona názvu souboru** | `pdf.filenameTemplate` (NOVÝ) | string (jeden, ne per-locale) |

Storage zůstává v `SystemConfig` — **žádná migrace schématu**. Pro `pdf.terms` se přidá nový row, pro `pdf.filenameTemplate` taky. Existující 7 řádků `pdf.*` zůstává beze změny.

`appendixItems: string[]` v `PdfConfig` typu se nahradí `terms: string` (HTML). `src/lib/pdf.ts:120` se opraví aby loadoval `pdf.terms`. `src/components/pdf/build-pdf-html.ts` přejde z `<ul><li>` rendru na `<div class="pdf-terms">${sanitizedHtml}</div>`.

## Implementace

### 1. Závislosti

```bash
pnpm add @tiptap/react @tiptap/starter-kit sanitize-html
pnpm add -D @types/sanitize-html
```

- **TipTap** pro rich text editor (headless, React, produkuje HTML).
- **sanitize-html** pro server-side XSS prevention. Whitelist: `p, br, strong, em, u, ul, ol, li, h2, h3, a` (bez `<script>`, `<img>`, `<iframe>`, atd.). Inline styly zakázat.

### 2. Server action — `src/actions/pdf-config.ts` (NOVÝ)

Pattern převzatý z `src/actions/email-config.ts`. Operace:

- `getPdfConfig()` — `requireAdmin()`, načte všechny `pdf.*` z `SystemConfig`, vrátí typed objekt:
  ```ts
  {
    title: { cs, en, de },
    subtitle1: { ... },
    subtitle2: { ... },
    legalText: { ... },
    appendixTitle: { ... },
    appendixHeading: { ... },
    terms: { cs, en, de }, // HTML
    footer: { ... },
    filenameTemplate: string, // např. '{serialNumber}_{carrierName}'
  }
  ```

- `updatePdfConfig(raw)` — `requireAdmin()`, Zod validace, sanitize `terms` přes `sanitize-html`, upsert každého klíče zvlášť do `SystemConfig`, audit log s `entity: 'pdf-config'` (i18n klíč existuje v `messages/cs.json:443` `entity_pdfconfig`? — pokud ne, přidat), `revalidatePath('/admin/pdf')`.

Zod schema (nový soubor `src/schemas/pdf-config.ts`):
```ts
const localeText = z.object({ cs: z.string(), en: z.string(), de: z.string() });
export const pdfConfigSchema = z.object({
  title: localeText,
  subtitle1: localeText,
  subtitle2: localeText,
  legalText: localeText,
  appendixTitle: localeText,
  appendixHeading: localeText,
  terms: localeText, // HTML, sanitized v action
  footer: localeText,
  filenameTemplate: z.string().min(1).max(200).regex(/^[\w{}\-_.]+$/, 'Pouze a-z, 0-9, _, -, ., {, }'),
});
```

### 3. API route — `src/app/api/admin/pdf/preview/route.ts` (NOVÝ)

POST endpoint, `requireAdmin()`. Body: rawConfig + locale. Sestaví **mock order** (statická data — fake orderer, fake carrier z ARES, 1 nakládka + 1 vykládka), zavolá `buildPdfHtml(mockOrder, rawConfig, locale, null)` + `puppeteer.launch()`, vrátí `application/pdf` Buffer.

Server action by mohla vrátit base64 PDF, ale streaming binary blobu přes API route je standardnější. Frontend:

```ts
const res = await fetch('/api/admin/pdf/preview', {
  method: 'POST',
  body: JSON.stringify({ config: rawConfig, locale: 'cs' }),
});
const blob = await res.blob();
window.open(URL.createObjectURL(blob));
```

Mock data ulož do `src/lib/pdf-preview-mock.ts` (sdílený s API route + případně testy). Mock order má fixed `serialNumber: '20260101/1'`, fake orderer/carrier — operátor poznává, že to není reálná objednávka.

### 4. Admin UI — `src/app/admin/pdf/page.tsx` + `pdf-config-form.tsx` (NOVÉ)

- `page.tsx` — server component, `getPdfConfig()` + `getTranslations`, render `<PdfConfigForm config={...} />`.
- `pdf-config-form.tsx` — `'use client'`, lang tabs (cs/en/de) jako v `email-config-form.tsx`, 7 textových polí, `<TermsEditor lang={lang} value={config.terms[lang]} onChange={...} />` pro rich text, filename template input (sdílený přes všechny jazyky, vykreslí se mimo lang taby).
- `terms-editor.tsx` (NOVÝ) — TipTap obal s toolbarem (bold/italic/UL/OL/H2/H3, link), `useEditor({ extensions: [StarterKit.configure({...})] })`. Toolbar inline, kompaktní.
- Tlačítka: **Náhled** (per locale, generates preview PDF) + **Uložit šablonu** + **Zahodit** (reload from server).
- Toast notifikace přes `useToast()` (existující helper, používá email-config-form).

### 5. Update PDF render — `src/lib/pdf.ts` + `src/components/pdf/build-pdf-html.ts`

- `pdf.ts:113-122` — přidat `terms: getText('pdf.terms')` do `PdfConfig`. Smazat TODO komentář na řádku 120 a `appendixItems: []`.
- `pdf.ts` — nově načíst `pdf.filenameTemplate` z `SystemConfig`. Funkce `renderFilenameTemplate(template, order)` — náhrada placeholderů `{serialNumber}`, `{carrierName}`, `{slug}`, sanitize výstup (`/[^\w\-_.]/g → '_'`). Použij ji při PDF download endpoint (najdi v `src/app/api/orders/[slug]/pdf/route.ts` nebo podobném, doplnit hledání).
- `build-pdf-html.ts` — `PdfConfig` type: `appendixItems: string[]` → `terms: string`. V appendix sekci render `<div class="pdf-terms">${pdfConfig.terms}</div>` místo `<ul>`. CSS doplnit `.pdf-terms { font-size: ...; line-height: ...; } .pdf-terms ul { ... } .pdf-terms p { ... }` aby bullety/odstavce vypadaly konzistentně.
- HTML escape: `terms` se NEnescapuje (je to už sanitized HTML), ostatní texty zůstávají přes `esc()`.

### 6. Admin navigace — `src/app/admin/admin-nav.tsx`

Přidat `'pdf'` do `BASE_LINKS` (před `emails`, abychom dodrželi pořadí dle docs):

```ts
const BASE_LINKS = ['users', 'orderers', 'pdf', 'emails', 'validation'];
```

i18n klíč `admin.pdf.title` v `messages/{cs,en,de}.json`.

### 7. i18n — `messages/{cs,en,de}.json`

Nová sekce `admin.pdf` s klíči pro labels: `title`, `description`, `tab*`, `field_title`, `field_subtitle1`, ..., `field_terms`, `field_filenameTemplate`, `placeholder_serialNumber`, `placeholder_carrierName`, `placeholder_slug`, `previewButton`, `previewError`, `save`, `saving`, `saved`, `discard`, atd. Plus `auditLog.entity_pdfconfig` ve všech 3 jazycích.

### 8. Seed — `prisma/seed.ts`

Přidat default value pro `pdf.terms` (placeholder smluvní podmínky v cs, klient si je dál upraví) a `pdf.filenameTemplate` (`{serialNumber}_{carrierName}`). Pomocí `upsert({ where: { key }, update: {}, create: {...} })` aby seed na již běžícím stacku neexistující řádky doplnil bez přepisu existujících.

## Kritické soubory

- `src/lib/pdf.ts:35-46` (load `pdf.*`), `:113-122` (PdfConfig build), `:120` (TODO smazat), `:???` (filenameTemplate render)
- `src/components/pdf/build-pdf-html.ts` (PdfConfig type + appendix render)
- `src/actions/email-config.ts` (vzor pro server action pattern)
- `src/app/admin/emails/email-config-form.tsx` (vzor pro lang tabs UI)
- `src/app/admin/admin-nav.tsx:8-10` (BASE_LINKS)
- `prisma/seed.ts:115-160` (kde se vytváří EmailConfig + SystemConfig)
- `messages/cs.json` sekce `admin.emails` jako šablona pro `admin.pdf`

## Verifikace (end-to-end)

1. `pnpm db:seed` na lokále — ověř že nové klíče `pdf.terms` a `pdf.filenameTemplate` v `SystemConfig`.
2. `pnpm dev`, login jako admin → /admin/pdf → uvidíš 7 polí + rich text editor + filename template input.
3. Přepni na **EN tab** → uprav `title`, **CS tab** zůstal nezměněn → save → reload → obě hodnoty perzistovány.
4. **Rich text:** napiš text, použij bold + bullet → klikni **Náhled** → otevře se PDF v novém okně, smluvní podmínky obsahují formátovaný text.
5. **Filename:** zadej `{serialNumber}_{carrierName}` → save → otevři confirmed objednávku → download PDF → file `<serial>_<carrier>.pdf` (sanitized — žádné lomítka).
6. **XSS test:** v rich textu zkus paste `<script>alert(1)</script>` → save → preview → script nezíská spustit (sanitize-html ho strippoval). Inspektor browseru ukáže že HTML v DB je čistý.
7. **Dev DB**: `pnpm db:studio` → `SystemConfig` má rows `pdf.title`, `pdf.terms`, `pdf.filenameTemplate`, hodnoty mají správné JSON shape.
8. Deploy na test stack (GH Actions Re-run) → ověř totéž na `https://test.objednavkypiva.cz/admin/pdf`.

## Co se NEdělá (explicit out-of-scope)

- ❌ Logo upload (storage, MIME validace, src do `<img>`) — odloženo, klient nepožádal.
- ❌ Reorder bullet pointů přetahováním — TipTap ListItem reordering v rich text editoru je out-of-the-box (drag handle), ale složitější. Pro MVP TipTap default UX stačí.
- ❌ Verzování konfigurace / undo. Audit log zachytí změny, manuální revert přes audit-log entry.
- ❌ A/B preview (dva configy vedle sebe). Pouze jeden aktuální.
