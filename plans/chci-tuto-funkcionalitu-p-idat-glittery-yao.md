# Plán: Lokální docs konvence + skill `/note` do `agent-dotclaude`

## Context

`~/Projects/@d4works/agent-dotclaude` je globální `.claude` repo dedikovaného Mac mini agenta
(deployuje se do `~/.claude`, používá ho Claude ve všech projektech na tom stroji). Cíl: přenést
konvenci projektové dokumentace, kterou používá `mtms-mobile-app` (index-first `docs/`, šablona,
pravidlo „zastaralý doc horší než žádný", oddělené commity), tak aby ji **používal každý projekt na
agent-stroji** — ale s jedním rozdílem oproti mtms:

- Na agent-stroji je `<projekt>/.claude/` **samostatný vnořený git repo** (`agent-dotclaude-<projekt>`),
  **gitignorovaný z klientského repa** (přes globální `core.excludesfile`). Klientská repa jsou často
  cizí a nesmí do nich spadnout Claude obsah.
- Proto docs **nesmí** jít do `<projekt>/docs/` (klientské repo), ale do **`<projekt>/.claude/docs/`**
  (Claude repo). Každá změna docs se commituje do **`.claude` repa**, odděleně od kódu.

Druhý krok: zpřístupnit skill `/note` (dnes žije jen na Jiřího hlavním stroji v
`~/.claude/skills/note/SKILL.md`) všem projektům na agent-stroji, s poznámkami ukládanými do
`.claude/docs/notes.md`.

## Rozhodnutí (potvrzená s uživatelem)

- **Vynucení commitu docs:** *jen konvence*, žádný hook. Stop-hook by kradl agentovi prefixovaný
  commit (`[ID] docs: …`) generickým `auto-sync`, commitoval rozpracované docs a běžel po každém tahu.
  Zapomenutý commit se sveze s příštím — garance se nevyplatí. Pravidlo „commituj každou změnu docs
  zvlášť do `.claude` repa" bude **silně napsané v globálním `CLAUDE.md`**.
- **Žádný `/docs` skill** — zakládání dokumentů zůstává na konvenci (agent zkopíruje `_TEMPLATE.md`
  a doplní řádek do indexu ručně, jako v mtms).
- **Struktura** = věrná kopie mtms documentation konvence: `features/`, `architecture/`, `README.md`
  (index), `_TEMPLATE.md`, `notes.md`. (mtms `plans/` se nereplikuje — na agent-stroji to pokrývá
  plan-mode `~/.claude/plans/`.)

## Cílové umístění docs v projektu

```
<projekt>/.claude/docs/
├── README.md         # index/mapa (čte se na startu session)
├── _TEMPLATE.md      # šablona nového dokumentu
├── notes.md          # volné poznámky přes /note (vzniká on-demand)
├── features/         # jeden doc na doménu
└── architecture/     # cross-cutting témata
```

---

## Změny v `~/Projects/@d4works/agent-dotclaude`

### 1. Globální `CLAUDE.md` — nová sekce o dokumentaci

Přidat novou sekci (vlož za stávající `## Složka .claude/ je samostatný config repo`, ať `.claude`
témata drží pohromadě). Behaviorální pravidlo platné pro všechny projekty:

```markdown
## Projektová dokumentace (`.claude/docs/`)

Detailní, behavior-level dokumentace projektu žije v `<projekt>/.claude/docs/` (uvnitř vnořeného
`.claude` repa — gitignorovaná z klientského repa). Vstupní bod je `.claude/docs/README.md` —
krátký index/mapa všech dokumentů.

- **Na startu session čti `.claude/docs/README.md`** (jen mapa). Konkrétní feature/architecture doc
  otevři teprve, když na té oblasti reálně pracuješ — NEnačítej všechny docs předem. Kontext má růst
  s úkolem, ne s velikostí projektu.
- **Udržuj docs v synchru:** kdykoli změníš chování feature nebo zjistíš něco neobvyklého, aktualizuj
  příslušný doc (a index v `README.md`, pokud doc přidáš/odebereš). Zastaralý doc je horší než žádný.
- **Commituj docs ZVLÁŠŤ a do `.claude` repa:** změny dokumentace jdou vždy do vlastního commitu,
  odděleně od kódu, vždy do `.claude` repa:
  `git -C <projekt>/.claude add docs && git -C <projekt>/.claude commit -m "[<ID>] docs: …"`.
  (Commit message anglicky dle pravidla výše.)
- `features/<domena>.md` — doména/sekce projektu; `architecture/<tema>.md` — cross-cutting témata.
- Volné poznámky přidávej skillem `/note` → ukládají se do `.claude/docs/notes.md` (a commitují se
  stejně jako ostatní docs).
```

### 2. Nová šablona `templates/docs/` (scaffold pro nové projekty)

`templates/` je už mechanismus „věci ke zkopírování do projektů". Přidat:

```
templates/docs/
├── README.md          # generický index skeleton (prázdné tabulky)
├── _TEMPLATE.md       # kopie z mtms docs/_TEMPLATE.md (verbatim)
├── features/.gitkeep
└── architecture/.gitkeep
```

**`templates/docs/README.md`** (generická verze mtms indexu — bez mtms-specifických řádků):

```markdown
# Projektová dokumentace

Index (mapa) veškeré projektové dokumentace. Žije v `.claude/docs/` (vnořený `.claude` repo —
gitignorovaný z klientského repa). Slouží mně (Claude) i lidem.

## Jak ho používám

- Na **startu session** čtu **jen tenhle soubor** — krátká mapa, ne obsah.
- Konkrétní detailní dokument otevřu **teprve když reálně pracuji na dané oblasti**.
- **Kontext tak roste s úkolem, ne s velikostí projektu.**

> **Pravidlo údržby:**
> - Když pracuji na oblasti nebo měním její chování, **aktualizuji příslušný doc**.
> - Když dokument **přidám/zruším**, upravím i tabulky v tomhle indexu.
> - **Neaktuální doc je horší než žádný.**
> - Každou změnu docs **commituju zvlášť do `.claude` repa** (viz globální `CLAUDE.md`).

## Organizace

- **`features/`** — jeden dokument na doménu / sekci projektu.
- **`architecture/`** — cross-cutting témata (stav, data/API, routing, auth, i18n, build…).
- **`_TEMPLATE.md`** — šablona pro nový dokument.
- **`notes.md`** — volné poznámky (skill `/note`).

## Features (domény)

| Dokument | Co popisuje | Stav |
|----------|-------------|------|
| _(zatím žádné)_ | | |

## Architecture (cross-cutting)

| Dokument | Co popisuje | Stav |
|----------|-------------|------|
| _(zatím žádné)_ | | |

## Legenda stavu

- ✅ **hotovo a aktuální** — soubor existuje a odpovídá kódu
- 🚧 **rozpracováno** — soubor existuje, ale není kompletní
- ⬜ **nezdokumentováno** — soubor zatím **NEEXISTUJE** (řádek je jen roadmapa; v tabulce holý název bez odkazu)
```

**`templates/docs/_TEMPLATE.md`** = zkopírovat doslova z
`/Users/jiri/Projects/mtms-mobile-app/docs/_TEMPLATE.md` (šablona s instrukčním HTML komentářem
a sekcemi Přehled / Uživatelské chování / Obrazovky / Komponenty / Stav & data flow / Okrajové
případy / Historie). Beze změn — je projektově neutrální.

### 3. `bin/new-project` — scaffold `.claude/docs/`

V bloku pro čerstvý projekt (`CLAUDE_EXISTS == 0`, kolem `mkdir -p "$CLAUDE_DIR/skills" …` na ~ř. 94)
přidat kopii docs skeletonu z templates. Spadne automaticky do iniciálního `git add -A` + commitu
(ř. 178–180), takže docs skeleton je v prvním commitu vnořeného repa:

```bash
# --- docs/ skeleton (projektová dokumentace) ---
if [[ -d "$HOME/.claude/templates/docs" ]]; then
  mkdir -p "$CLAUDE_DIR/docs"
  cp -R "$HOME/.claude/templates/docs/." "$CLAUDE_DIR/docs/"
  c_ok "docs/ (index README + _TEMPLATE.md + features/ architecture/)"
fi
```

Dále do generovaného `$CLAUDE_DIR/CLAUDE.md` (heredoc kolem ř. 113–142) přidat krátkou sekci, aby
`/note` znal cestu a neptal se:

```markdown
## Poznámky
- Projektové poznámky jsou v `.claude/docs/notes.md`, přidávají se skillem `/note`.
```

### 4. Nový skill `skills/note/SKILL.md`

Zkopírovat z `/Users/jiri/.claude/skills/note/SKILL.md`
(reálně `/Users/jiri/Documents/_sync/.claude/skills/note/SKILL.md`) do
`agent-dotclaude/skills/note/SKILL.md`, s těmito úpravami pro agent-stroj:

- **Default cesta** v kroku 1: `docs/notes.md` → **`.claude/docs/notes.md`** (poznámky žijí s docs ve
  vnořeném repu). „Projektový CLAUDE.md", do kterého skill cestu zapisuje, je na agent-stroji
  `.claude/CLAUDE.md` — `new-project` ho už pre-seedne sekcí `## Poznámky`, takže se skill nebude ptát.
- **Krok 7 (commit):** stávající „soubor sám od sebe necommituj" změnit na soulad s docs konvencí —
  poznámka v `.claude/docs/` se commituje do `.claude` repa stejně jako ostatní docs
  (`git -C <projekt>/.claude commit -m "[<ID>] docs: note …"`). Necommituj jen tělo klientského repa.
- Zbytek (formát, deduplikace, sekce, TOC, AskUserQuestion na duplicitu) **beze změny**.

### 5. `README.md` (agent-dotclaude) — zdokumentovat nové díly

Doplnit krátký odstavec: (a) konvence `.claude/docs/` (index-first, oddělené commity do `.claude`
repa), (b) skill `/note` → `.claude/docs/notes.md`, (c) že `templates/docs/` scaffolduje `new-project`.
`skills/` i `templates/` jsou v allowlist `.gitignore` už teď.

### 6. `.gitignore` — beze změny

Allowlist (`/*`, `/.*` + `!/skills/`, `!/templates/`) trefuje vnořené soubory (stávající
`skills/task/SKILL.md` a `templates/release/SKILL.md` jsou trackované) → `skills/note/SKILL.md`
i `templates/docs/**` budou trackované bez úpravy `.gitignore`.

---

## Soubory k vytvoření / úpravě (souhrn)

| Akce | Cesta |
|------|-------|
| upravit | `agent-dotclaude/CLAUDE.md` (nová sekce dokumentace) |
| vytvořit | `agent-dotclaude/templates/docs/README.md` |
| vytvořit | `agent-dotclaude/templates/docs/_TEMPLATE.md` (kopie z mtms) |
| vytvořit | `agent-dotclaude/templates/docs/features/.gitkeep` |
| vytvořit | `agent-dotclaude/templates/docs/architecture/.gitkeep` |
| upravit | `agent-dotclaude/bin/new-project` (scaffold docs/ + `## Poznámky` v CLAUDE.md) |
| vytvořit | `agent-dotclaude/skills/note/SKILL.md` (kopie + úprava cesty/commitu) |
| upravit | `agent-dotclaude/README.md` (dokumentace nových dílů) |

## Verifikace (end-to-end)

1. **Scaffold nového projektu:** `new-project test-docs /tmp/test-docs` → ověřit:
   - `ls -R /tmp/test-docs/.claude/docs` ukáže `README.md`, `_TEMPLATE.md`, `features/`, `architecture/`.
   - `git -C /tmp/test-docs/.claude ls-files docs` → docs jsou v iniciálním commitu vnořeného repa.
   - `/tmp/test-docs/.claude/CLAUDE.md` obsahuje sekci `## Poznámky` s cestou `.claude/docs/notes.md`.
   - Poté smazat testovací projekt.
2. **Skill `/note`:** v projektu se scaffoldnutým `.claude/docs/` spustit `/note "test poznámka"` →
   vznikne/aktualizuje se `.claude/docs/notes.md`, skill se neptá na cestu (vzal ji z CLAUDE.md),
   navrhne commit do `.claude` repa.
3. **Index repa:** `git -C ~/Projects/@d4works/agent-dotclaude status` → nové soubory
   (`skills/note/SKILL.md`, `templates/docs/**`) jsou **tracked** (ne ignored); `CLAUDE.md`,
   `README.md`, `bin/new-project` jako modified.
4. **Render:** vizuálně zkontrolovat, že nová sekce v `CLAUDE.md` a `templates/docs/README.md`
   se renderují správně (tabulky, blockquote).

## Commit & deploy

- Změny commitnout v repu `agent-dotclaude` (samostatný repo). Logické rozdělení: jeden commit pro
  konvenci docs (`CLAUDE.md` + `templates/docs/` + `bin/new-project` + `README.md`), druhý pro skill
  `/note` (`skills/note/`). Commit messages dle konvence repa.
- **Pozn.:** úpravy jsou ve **zdrojovém repu** `~/Projects/@d4works/agent-dotclaude`. Na agent-stroj
  (`~/.claude`) se dostanou existujícím deploy mechanismem (clone/pull + merge dle `README.md`) —
  není součástí tohoto úkolu, jen na to upozornit. `new-project` čte šablony z `$HOME/.claude/templates/`,
  takže docs scaffold funguje až po deployi na agent-stroj.
- Existující projekty (už mají `.claude/` repo) `new-project` přeskakuje → do nich se `.claude/docs/`
  doplní ručně zkopírováním `~/.claude/templates/docs/` (volitelný follow-up, mimo tento plán).
