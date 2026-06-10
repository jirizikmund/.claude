---
name: commit
description: Create a git commit — analyzes changes, offers message format options, ignores build artifacts
disable-model-invocation: true
---

# Commit Skill

Vytvoř git commit pro aktuální změny. Postupuj přesně podle těchto kroků:

## Krok 1: Zjisti kontext

**Číslo tasku** zjisti z těchto zdrojů (v pořadí priority):
1. Kontext konverzace — uživatel mohl číslo tasku zmínit dříve, nebo se na tasku pracovalo
2. Název aktuální branch (vzor: `feat/XXXX`, `fix/XXXX`, `hotfix/XXXX` apod. → číslo je XXXX)
3. Pokud se číslo nepodaří zjistit z žádného zdroje, zeptej se uživatele

Spusť paralelně:
- `git branch --show-current` — zjisti aktuální branch
- `git status` — zjisti stav souborů (nikdy nepoužívej `-uall`)
- `git diff` a `git diff --cached` — zjisti obsah změn
- `git log --oneline -5` — zjisti styl posledních commitů

## Krok 2: Nabídni formát commit message

Na základě zjištěného kontextu nabídni uživateli **3 možnosti**:

1. **Conventional commit** — formát `feat: popis`, `fix: popis`, `refactor: popis` atd.
2. **S číslem tasku** — formát `(#XXXX) typ: popis` (kde XXXX je číslo tasku z branch). Pokud číslo tasku nebylo nalezeno, upozorni uživatele.
3. **Vlastní** — uživatel zadá vlastní zprávu

Pro každou možnost navrhni konkrétní text commit message na základě analýzy diffu. Tedy uživatel uvidí:
```
1) feat: add permit checklist tab
2) (#1057) feat: add permit checklist tab
3) Vlastní zpráva
```

**Počkej na odpověď uživatele.** Nepokračuj, dokud si uživatel nevybere.

## Krok 3: Vyber soubory k commitu

Analyzuj změněné soubory a rozděl je na:

**Zahrnout** — soubory přímo související s aktuální prací (zdrojový kód, typy, testy, konfigurace relevantní pro task)

**Ignorovat** — soubory, které nesouvisí s aktuální prací:
- Build artefakty (`dist/`, `build/`, `.next/`, `amplify/backend/*/build/`, `**/lib/`, `**/*.js.map`)
- Automaticky generované soubory (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`) — pokud není součástí záměrné změny závislostí
- Soubory typu `*.d.ts` v build výstupech (ale NE v `src/`)
- Dočasné soubory, logy, cache

Ukaž uživateli seznam souborů, které budeš stagovat, a seznam těch, které ignoruješ. **Počkej na potvrzení.**

## Krok 4: Commitni

1. Stagni vybrané soubory pomocí `git add` s konkrétními cestami (NIKDY nepoužívej `git add .` nebo `git add -A`)
2. Commitni se zvolenou zprávou
3. Zobraz výsledek commitu

## Pravidla

- **NIKDY** nepřidávej do commit message zmínky o Claude Code, AI, nebo Co-Authored-By
- **NIKDY** nepoužívej emoji v commit message
- **NIKDY** neměň git historii (žádný amend, rebase, force push) bez explicitního souhlasu uživatele
- **NIKDY** necommituj soubory obsahující secrets (.env, credentials, tokeny)
- Commit message piš v angličtině, komunikuj s uživatelem česky
- Pokud nejsou žádné změny k commitnutí, informuj uživatele a skonči
- Argument `$ARGUMENTS` může obsahovat dodatečné instrukce od uživatele (např. popis co commitnout)
