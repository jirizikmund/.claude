# Plán: Markdown a Mermaid rendering v DocsModal

## Kontext

DocsModal zobrazuje raw markdown text v `<pre>` — nefunguje formátování (nadpisy, tabulky, bold) ani Mermaid diagramy. Potřebuji přidat markdown renderer a Mermaid support.

## Změny

### 1. Žádné nové dependencies — CDN loading

Načtení `marked` a `mermaid` z CDN dynamicky v `useEffect`:
- `https://cdn.jsdelivr.net/npm/marked/marked.min.js` — markdown→HTML parser
- `https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js` — diagram renderer

Výhody: žádný dopad na bundle size, žádné nové deps v package.json.

### 2. `src/Admin/ChecklistTester/DocsModal.tsx`
- Dynamické načtení `marked` a `mermaid` z CDN přes `<script>` tag v `useEffect`
- `window.marked.parse(markdown)` → HTML string
- `dangerouslySetInnerHTML` pro rendering (bezpečné — obsah je naše vlastní dokumentace, ne user input)
- Po renderování HTML: najít všechny `<code class="language-mermaid">` bloky a nahradit SVG přes `window.mermaid.run()`
- Basic CSS styly pro tabulky, nadpisy, code bloky

### Klíčové soubory
- `src/Admin/ChecklistTester/DocsModal.tsx` — hlavní změna
- Žádné změny v package.json

## Ověření
- Otevřít modal, ověřit formátování nadpisů, tabulek, bold textu
- Ověřit Mermaid diagramy (flowchart, gantt, stateDiagram)
