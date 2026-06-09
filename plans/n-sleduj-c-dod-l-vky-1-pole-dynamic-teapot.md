# Plán: tři dodělávky (PSČ šířka, právní text rich-text, PDF stránkování)

## Context

Tři nezávislé UX/PDF úpravy v BOSS:

1. **PSČ pole je úzké** v ContactCard (108px) — vejde se 5-místné PSČ, ale s mezerou ("150 00") to vypadá natěsno. Sdílená komponenta, mění se i pro carrier i pro item delivery contact.
2. **Právní text pod cenou** v adminu má aktuálně jen `<textarea>` s plain textem. Smluvní podmínky už mají TipTap rich-text editor — totéž zavést pro právní text. Aby admin mohl zformátovat odstavce, tučné, seznamy.
3. **PDF nemá stránkování** — uživatel chce "Strana 1/3" v existujícím footer divu, vpravo. Aktuálně footer obsahuje jen `config.footer` text (centrovaný copyright/disclaimer).

Po implementaci: PSČ pohodlné na desktopu i mobilu, admin formátuje právní text WYSIWYG, PDF jasně ukazuje pozici v dokumentu (= užitečné při tisku, archivaci, kontrole).

---

## Rozhodnutí (potvrzená uživatelem)

- **PSČ width**: `w-[140px]` (z 108px)
- **Migrace plain → HTML pro `legalText`**: Žádná, admin po deployi otevře form a uloží (TipTap při saveu wrapne plain text do `<p>`). Komentář v kódu upozorní budoucího vývojáře.
- **Footer layout pro stránkování**: Page number (`Strana X/Y`) se zařadí do existujícího footer divu, úplně vpravo. config.footer text zůstane uprostřed.
- **Formát**: `Strana 1/3` (slash). Lokalizace: cs="Strana", en="Page", de="Seite".

---

## Dodělávka 1: PSČ pole širší v ContactCard

**Změna** (single-line):

`/Users/jiri/Projects/beer-order-sheet-system/src/components/ui/contact-card.tsx:248`
- `className="w-[108px] shrink-0"` → `className="w-[140px] shrink-0"`

Šíří se na obou místech automaticky (sdílená komponenta používaná v `OrderForm` line 978–1039 i `OrderItemForm` line 286–333).

**Verifikace**: `pnpm dev`, otevřít editaci objednávky → carrier card edit → vizuální kontrola PSČ pole. Stejně v editaci item kontaktu.

---

## Dodělávka 2: Právní text pod cenou — rich text editor

### Strategie

`legalText` se mění z plain (`localized` max 8000) na HTML (`localizedHtml` max 50_000). Editor: znovupoužít existující `TermsEditor` (TipTap, generický). Sanitizace přes existující `sanitizeTermsHtml`. PDF inject raw (analog k `terms`). **Bez data migrace** — admin po deployi otevře `/admin/pdf` a uloží form pro každý jazyk (TipTap při saveu naformátuje plain text do `<p>`).

### Komponenta — minimální refactor

Editor už je generický a stačí jen přejmenovat (rename = sémantická konzistence — `terms` i `legalText` ho používají, jméno `TermsEditor` by matlo).

**`/Users/jiri/Projects/beer-order-sheet-system/src/app/admin/pdf/terms-editor.tsx`** → přejmenovat soubor na `rich-text-editor.tsx`, funkci `TermsEditor` na `RichTextEditor`. Aktualizovat komentář u `useEditor` aby nemluvil specificky o "PDF terms-and-conditions appendix" → obecně "PDF rich-text fields (terms, legal text)".

### Změny v pořadí

#### Krok 1 — schema

**`/Users/jiri/Projects/beer-order-sheet-system/src/schemas/pdf-config.ts:22`**
- `legalText: localized` → `legalText: localizedHtml`

#### Krok 2 — refactor editoru

**Rename**: `src/app/admin/pdf/terms-editor.tsx` → `src/app/admin/pdf/rich-text-editor.tsx`. Funkce `TermsEditor` → `RichTextEditor`. Komentář u `useEditor` (ř. 23-27) zobecnit. Žádný behaviorální change.

#### Krok 3 — form použije RichTextEditor pro `legalText`

**`/Users/jiri/Projects/beer-order-sheet-system/src/app/admin/pdf/pdf-config-form.tsx`**

- Ř. 10 import: `import { TermsEditor } from './terms-editor';` → `import { RichTextEditor } from './rich-text-editor';`
- Ř. 17-25 (TEXT_FIELDS): odstranit záznam `{ key: 'legalText', multiline: true }` (legalText už není textarea).
- Ř. 146-154 (rich-text section): za stávajícím `<RichTextEditor value={data.terms[lang]} ...>` (použít rename) přidat analogický blok pro legalText:
  ```tsx
  <div>
    <label className="mb-1 block text-xs text-muted-foreground">{t('field_legalText')}</label>
    <p className="mb-2 text-xs text-muted-foreground">{t('field_legalTextHint')}</p>
    <RichTextEditor
      value={data.legalText[lang]}
      onChange={(html) => setLocalized('legalText', lang, html)}
    />
  </div>
  ```
- Pořadí: `legalText` editor logicky před `terms` (tak jak je v PDF: legal text na page 1 pod cenou, terms na page 2 jako příloha) — nebo zachovat původní pořadí TEXT_FIELDS, kde legalText byl mezi `subtitle2` a `appendixTitle`. Doporučení: zařadit nový `legalText` editor MEZI `TEXT_FIELDS` blok a `terms` editor (logické místo).

#### Krok 4 — i18n (přidat `field_legalTextHint`)

`messages/cs.json`, `messages/en.json`, `messages/de.json` (sekce `admin.pdf`):
- cs: `"field_legalTextHint": "Editor podporuje tučné, kurzívu, seznamy, nadpisy. HTML se před uložením sanitizuje."`
- en: `"field_legalTextHint": "Editor supports bold, italic, lists, and headings. HTML is sanitized server-side before saving."`
- de: `"field_legalTextHint": "Editor unterstützt Fett, Kursiv, Listen und Überschriften. HTML wird vor dem Speichern serverseitig bereinigt."`

#### Krok 5 — server action sanitizuje legalText

**`/Users/jiri/Projects/beer-order-sheet-system/src/actions/pdf-config.ts`**

- Ř. 90-94: rozšířit o `sanitizedLegalText`:
  ```ts
  const sanitizedLegalText: LocalizedText = {
    cs: sanitizeTermsHtml(data.legalText.cs),
    en: sanitizeTermsHtml(data.legalText.en),
    de: sanitizeTermsHtml(data.legalText.de),
  };
  ```
- Ř. 99-102 (writes): rozšířit ternární výraz:
  ```ts
  value: field === 'terms' ? sanitizedTerms : field === 'legalText' ? sanitizedLegalText : data[field],
  ```
- Ř. 119-123 (auditLog after): `terms: sanitizedTerms` → `terms: sanitizedTerms, legalText: sanitizedLegalText`.

#### Krok 6 — PDF render injectuje raw HTML

**`/Users/jiri/Projects/beer-order-sheet-system/src/components/pdf/build-pdf-html.ts:219`**
- `<div class="legal-text">${esc(config.legalText)}</div>` → `<div class="legal-text">${config.legalText ?? ''}</div>`
- Komentář (analog k `termsHtml` na ř. 172-175):
  ```ts
  // config.legalText is pre-sanitized HTML (sanitize-html in updatePdfConfig).
  // Inject raw — DO NOT escape — so paragraphs, bold, lists render.
  // NOTE: Legacy plain-text values stored before this commit may render
  // as a single line until the admin re-saves the form (TipTap wraps
  // plain text into <p> on next save).
  const legalTextHtml = config.legalText ?? '';
  ```

#### Krok 7 — CSS pro nested HTML elementy v `.legal-text`

**`/Users/jiri/Projects/beer-order-sheet-system/src/components/pdf/build-pdf-html.ts:396`**

Existující jeden řádek:
```css
.legal-text { margin-top: 16px; font-size: 10px; font-weight: 700; line-height: 1.5; }
```

Rozšířit (analog k `.appendix-terms` ř. 400-406):
```css
.legal-text { margin-top: 16px; font-size: 10px; font-weight: 700; line-height: 1.5; }
.legal-text p { margin: 0 0 4px; }
.legal-text ul, .legal-text ol { padding-left: 18px; margin: 4px 0; }
.legal-text li { margin-bottom: 2px; }
.legal-text strong { font-weight: 700; }
.legal-text em { font-style: italic; font-weight: 700; }
.legal-text a { color: #111; text-decoration: underline; }
.legal-text h2, .legal-text h3, .legal-text h4 { font-size: 11px; font-weight: 700; margin: 6px 0 4px; }
```

#### Krok 8 — preview route sanitize legalText

**`/Users/jiri/Projects/beer-order-sheet-system/src/app/api/admin/pdf/preview/route.ts`** (kolem ř. 44-57)

Pokud admin preview rovnou injectuje config.legalText z form (před save), musí být sanitizováno před `buildPdfHtml`. Analog k existujícímu `sanitizeTermsHtml(cfg.terms[locale])` — přidat to samé pro `legalText`.

### Verifikace E2E

1. `pnpm dev`, login admin, `/admin/pdf`.
2. Sekce "Právní text pod cenou" má teď rich-text editor (toolbar B/I/H2/H3/seznam/citace).
3. Vyplnit nějakou kombinaci formátování (paragraf, bold, kurzíva, seznam) → "Náhled" → kontrola PDF: legal-text blok nad "Vystavil" má formátování.
4. Save → kontrola DB: `SELECT value FROM "SystemConfig" WHERE key='pdf.legalText';` JSON má HTML s `<p>`, `<strong>`, atd.
5. Stáhnout PDF stávající objednávky (nikoli preview) → ověřit legal blok.
6. Test starého chování: před krokem 4 zkusit stáhnout PDF — pokud původní DB hodnota byla plain text, render zobrazí plain řádek (degraded, expected). Po kroku 4 už korektně.

---

## Dodělávka 3: PDF stránkování — uvnitř footer divu, vpravo

### Strategie

Stávající `.footer` div (s `config.footer` textem, absolutně positioned bottom 10mm) zůstane. Nahradíme jej **Puppeteer's footerTemplate** s 3-column layoutem:
- levý sloupec: prázdný (spacer)
- střední: `config.footer` text (jak dnes)
- pravý: `Strana X/Y`

Puppeteer footerTemplate dostane `<span class="pageNumber">` a `<span class="totalPages">` (Puppeteer je injectuje dynamicky podle skutečného počtu stran). Lokalizovaný label ("Strana"/"Page"/"Seite") + lokalizovaný `config.footer` text se passthroughne přes parametr v `renderHtmlToPdf`.

**Dopady**:
- Stávající HTML `.footer` div v `buildPdfHtml` se odstraňuje (přesouvá do Puppeteer footer template). CSS `.footer` v `pdfStyles` se odstraňuje.
- Visuálně se posune ze ~10mm od kraje papíru na ~5mm (Puppeteer kreslí footer v 15mm bottom marginu, footer template má vlastní default padding). Detail bude vidět při testu — můžeme doladit padding inline.
- Multi-page support: Puppeteer footer se opakuje na každé stránce automaticky (na rozdíl od stávajícího HTML `.footer`, který se opakuje jen v každém `<div class="page">`).
- `.page` v CSS musí mít `min-height: 297mm` → `min-height: 282mm` (= 297 − 15 mm bottom margin), jinak Chromium zlomí stránku navíc.

### Změny v pořadí

#### Krok 1 — i18n label `pageOf`

**`/Users/jiri/Projects/beer-order-sheet-system/src/components/pdf/build-pdf-html.ts:241-350`** (`getLabels`)

Přidat klíč do všech 3 lokálů:
- cs: `pageOf: 'Strana'`
- en: `pageOf: 'Page'`
- de: `pageOf: 'Seite'`

#### Krok 2 — `buildPdfHtml` vrací `{ html, footerText, pageLabel }`

**`/Users/jiri/Projects/beer-order-sheet-system/src/components/pdf/build-pdf-html.ts:17-22`**

Změna návratového typu:
```ts
export function buildPdfHtml(
  order: PdfOrderData, config: PdfConfig, locale: string, variant: PdfVariant,
): { html: string; footerText: string; pageLabel: string }
```

Na konci `buildPdfHtml` (ř. ~238): `return { html: '<!DOCTYPE html>...', footerText: config.footer ?? '', pageLabel: labels.pageOf };`

#### Krok 3 — odstranit HTML `.footer` div

**`/Users/jiri/Projects/beer-order-sheet-system/src/components/pdf/build-pdf-html.ts:170`**

- Smazat řádek `const footerHtml = config.footer ? \`<div class="footer">${esc(config.footer)}</div>\` : '';`
- Ř. 220-221, 234-235: odstranit `${footerHtml}` z obou stránek.

#### Krok 4 — odstranit `.footer` CSS

**`/Users/jiri/Projects/beer-order-sheet-system/src/components/pdf/build-pdf-html.ts:398`**
- Smazat řádek `.footer { position: absolute; bottom: 10mm; left: 20mm; right: 20mm; ... }`

#### Krok 5 — `.page` min-height úprava

**`/Users/jiri/Projects/beer-order-sheet-system/src/components/pdf/build-pdf-html.ts:359`**
- `.page { ... min-height: 297mm; ... }` → `.page { ... min-height: 282mm; ... }`
- Důvod: Puppeteer bottom margin 15mm ubírá z 297mm content area. Pokud `.page` zachová 297mm, Chromium vytvoří navíc page break.

#### Krok 6 — `renderHtmlToPdf` akceptuje footer options

**`/Users/jiri/Projects/beer-order-sheet-system/src/lib/pdf.ts:150`**

Změna signatury:
```ts
export async function renderHtmlToPdf(
  html: string,
  opts?: { footerText?: string; pageLabel?: string },
): Promise<Buffer>
```

Uvnitř (před `page.pdf` call):
```ts
// HTML escape pro inline footer template — config.footer může obsahovat
// uživatelem zadaná data, takže escape proti '<', '>', '&'.
const escFooter = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

const footerText = escFooter(opts?.footerText ?? '');
const pageLabel = escFooter(opts?.pageLabel ?? 'Page');

// Puppeteer footerTemplate quirks:
// - default font-size is 0; must set inline
// - <span class="pageNumber"> a <span class="totalPages"> jsou
//   Puppeteer-specific, vyplní se dynamicky
// - layout přes <table> kvůli stabilitě napříč Chromium verzemi
//   (flex občas nefunguje v footer contextu)
const footerTemplate = `
<div style="font-size: 8px; color: #999; width: 100%; padding: 4px 20mm 0 20mm; border-top: 1px solid #eee; font-family: Helvetica, Arial, sans-serif; box-sizing: border-box;">
  <table style="width: 100%; border-collapse: collapse;"><tr>
    <td style="width: 33%;"></td>
    <td style="width: 34%; text-align: center;">${footerText}</td>
    <td style="width: 33%; text-align: right;">${pageLabel} <span class="pageNumber"></span>/<span class="totalPages"></span></td>
  </tr></table>
</div>`;
```

Změnit `page.pdf`:
```ts
const pdfBuffer = await page.pdf({
  format: 'A4',
  printBackground: true,
  displayHeaderFooter: true,
  headerTemplate: '<div></div>',
  footerTemplate,
  margin: { top: '0', bottom: '15mm', left: '0', right: '0' },
  timeout: PAGE_TIMEOUT_MS,
});
```

#### Krok 7 — všichni callers předávají footer options

**`/Users/jiri/Projects/beer-order-sheet-system/src/lib/pdf.ts:124-128`** (`generateOrderPdf`)
```ts
const { html, footerText, pageLabel } = buildPdfHtml(pdfOrder, pdfConfig, locale, variant);
return await renderHtmlToPdf(html, { footerText, pageLabel });
```

**`/Users/jiri/Projects/beer-order-sheet-system/src/app/api/admin/pdf/preview/route.ts`** (kolem ř. 46-62) — analogická úprava: `const { html, footerText, pageLabel } = buildPdfHtml(...)`, `await renderHtmlToPdf(html, { footerText, pageLabel })`.

### Verifikace E2E

1. `pnpm dev`, otevřít existující objednávku.
2. "Stáhnout PDF" → otevřít.
3. **Strana 1**: dolní pruh = thin border-top + 3-column řádek:
   - vlevo prázdné
   - uprostřed: text z `config.footer` (firemní disclaimer/copyright)
   - vpravo: `Strana 1/2`
4. **Strana 2** (appendix): tentýž footer, ale `Strana 2/2`.
5. Změnit jazyk: `?lang=en` query nebo language switcher → `Page 1/2`.
6. Test admin preview: `/admin/pdf` → "Náhled" → stejný formát.
7. Edge case: extra dlouhá objednávka (15+ items) → `Strana 1/3`, `Strana 2/3`, `Strana 3/3`.

---

## Pořadí commitů (conventional commits)

Tři dodělávky jsou nezávislé. Doporučené pořadí:

1. **`feat(ui): widen ContactCard ZIP input`** (dodělávka 1, single line, zero risk)
2. **`feat(pdf): page numbering in footer`** (dodělávka 3, středně izolované — Puppeteer + CSS)
3. **`feat(admin/pdf): rich-text editor for legal text`** (dodělávka 2, nejkomplexnější — schema + UI + sanitizace + render + i18n)

Každý commit verifikovat samostatně (`pnpm dev` + smoke test) před dalším.

---

## Critical files

- `/Users/jiri/Projects/beer-order-sheet-system/src/components/ui/contact-card.tsx`
- `/Users/jiri/Projects/beer-order-sheet-system/src/app/admin/pdf/pdf-config-form.tsx`
- `/Users/jiri/Projects/beer-order-sheet-system/src/app/admin/pdf/terms-editor.tsx` → rename to `rich-text-editor.tsx`
- `/Users/jiri/Projects/beer-order-sheet-system/src/actions/pdf-config.ts`
- `/Users/jiri/Projects/beer-order-sheet-system/src/components/pdf/build-pdf-html.ts`
- `/Users/jiri/Projects/beer-order-sheet-system/src/lib/pdf.ts`
- `/Users/jiri/Projects/beer-order-sheet-system/src/app/api/admin/pdf/preview/route.ts`
- `/Users/jiri/Projects/beer-order-sheet-system/src/schemas/pdf-config.ts`
- `/Users/jiri/Projects/beer-order-sheet-system/messages/{cs,en,de}.json`

---

## Otevřené body / poznámky

- **Po deployi**: připomenout uživateli, ať otevře `/admin/pdf` a uloží form pro každý jazyk (cs/en/de). TipTap při saveu wrappuje plain text do `<p>`, čímž se data v DB konzistentně přepnou na HTML formát. Bez tohoto kroku se starý plain-text legalText vyrenderuje jako jeden řádek bez paragrafů (degraded ale ne broken).
- **Test/prod parity**: dodělávky se liší jen kódem, žádné DB schema změny. Migrace je nepotřebná. Lze nasadit běžnou cestou (deploy.sh).
- **Pending monitoring úkoly** (memory): zombie fix `init: true` + prod deploy + Netdata verifikace zůstávají otevřené. Po těchto třech dodělávkách doporučuji řešit i je.
