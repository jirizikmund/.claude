---
name: note
description: Přidá volně psanou projektovou poznámku do souboru poznámek (standardně docs/notes.md). Poznámku srozumitelně zformuluje, zařadí do správné sekce, ohlídá duplicity a udržuje obsah na začátku souboru. Použij, když uživatel zadá /note nebo chce uložit poznámku k projektu.
---

# /note — projektové poznámky

Vstupem je volně (bodově) psaná poznámka od uživatele: `$ARGUMENTS`. Může se týkat čehokoliv — architektury, technologií, funkcionality, UI, rozhodnutí…

## Postup

### 1. Zjisti cestu k souboru poznámek
- Podívej se do projektového `CLAUDE.md`, jestli je v něm definovaná cesta k souboru poznámek (hledej sekci nebo řádek zmiňující „poznámky" / „notes").
- Pokud cesta definovaná **není**, zeptej se uživatele (AskUserQuestion), kam poznámky ukládat. Jako doporučenou výchozí volbu nabídni `docs/notes.md`.
- Zvolenou cestu poté **zapiš do projektového `CLAUDE.md`** (např. sekce `## Poznámky` s řádkem `- Projektové poznámky jsou v docs/notes.md, přidávají se skillem /note`), aby se skill příště už neptal. Pokud `CLAUDE.md` neexistuje, vytvoř ho jen s touto sekcí.

### 2. Zjisti aktuální datum a čas
Spusť `date '+%Y-%m-%d %H:%M'`. Nikdy čas neodhaduj z hlavy.

### 3. Načti soubor poznámek
- Pokud neexistuje, vytvoř ho (včetně složky) se základní strukturou — viz formát níže.
- Pokud existuje, přečti ho celý, ať znáš všechny sekce a existující poznámky.

### 4. Zformuluj poznámku
- Z bodového zadání napiš srozumitelný, plynulý text (1 odstavec, případně krátký seznam, pokud to obsahu sedí).
- **Zachovej všechna fakta ze zadání a žádná nepřidávej.** Stylizuj, ale nedomýšlej.
- Piš jazykem, kterým je psaný zbytek souboru (u nového souboru jazykem zadání).
- Poznámce dej krátký tučný titulek vystihující téma.

### 5. Zkontroluj duplicity
Porovnej novou poznámku s existujícími (tematicky, ne jen textově):
- Pokud už existuje poznámka na stejné nebo hodně podobné téma, **upozorni uživatele**: cituj existující poznámku a srozumitelně popiš, v čem se nová liší (co přidává, co mění, co si odporuje).
- Zeptej se (AskUserQuestion), co udělat: **nahradit** / **sloučit do jedné** / **přidat jako samostatnou** / **zrušit**.
- Při nahrazení nebo sloučení zachovej původní datum vytvoření a doplň datum úpravy.

### 6. Zařaď do správné sekce
- Vyber existující sekci, do které poznámka tematicky patří.
- Pokud žádná nesedí, vytvoř novou sekci s výstižným názvem.
- Nově vzniklou sekci přidej i do obsahu na začátku souboru.

### 7. Ulož a aktualizuj obsah
- Vlož poznámku na konec zvolené sekce.
- Zkontroluj, že obsah (TOC) na začátku souboru odpovídá skutečným sekcím; případně ho oprav.
- Nakonec uživateli krátce shrň: do jaké sekce poznámka šla a jak byla zformulovaná.
- Soubor sám od sebe necommituj; commituj jen pokud to vyžadují instrukce projektu nebo o to uživatel požádá.

## Formát souboru

Metadata o vytvoření/úpravě jsou vždy v hranatých závorkách: `*[Vytvořeno: …]*`, případně `*[Vytvořeno: … | Upraveno: …]*`.

```markdown
# Poznámky k projektu

## Obsah
- [Architektura](#architektura)
- [UI](#ui)

## Architektura

**Titulek poznámky**
Text poznámky srozumitelně zformulovaný do jednoho odstavce.
*[Vytvořeno: 2026-06-10 14:32]*

**Jiná poznámka**
Text další poznámky.
*[Vytvořeno: 2026-05-02 09:15 | Upraveno: 2026-06-10 14:40]*

## UI

**Titulek**
Text.
*[Vytvořeno: 2026-06-10 14:35]*
```

## Zásady
- Jedna poznámka = jedno téma. Pokud zadání obsahuje víc nesouvisejících témat, rozděl ho na víc poznámek (a každou zařaď zvlášť).
- Nikdy nemaž ani nepřepisuj existující poznámky bez potvrzení uživatele.
- Sekce drž tematicky široké (Architektura, Technologie, Funkcionalita, UI…), ať se soubor nerozpadne na desítky mini-sekcí.
