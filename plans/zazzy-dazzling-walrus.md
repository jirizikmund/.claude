# Plán — `/release` skill pro BOSS + UI changelog modal

## Context

Uživatel chce mít opakovatelný release workflow + uživatelům aplikace ukázat, **co bylo přidáno v každé verzi**. Doposud:

- Verze v `package.json` (`0.1.0`, statická)
- Žádný changelog
- Žádné git tagy
- Build badge v UI ukazuje deploy timestamp + commit SHA, ale neříká uživateli „co se změnilo"

Cílem je:

1. **Skill `/release`** — Claude vede uživatele přes bump verze, vygeneruje user-friendly souhrn změn z git logu, commit + tag, vše lokálně bez push/deploy.
2. **UI changelog modal** — v profile menu nad „Odhlásit se" tlačítko `Verze X.Y.Z(N) DD.M.YYYY`. Klik otevře modal s celou historií verzí (nejnovější nahoře, scroll), kde každá verze má hlavičku ve stejném formátu + odrážkový souhrn změn.

## Decisions (z dotazů)

- **Skill umístění**: project-local — `/Users/jiri/Projects/beer-order-sheet-system/.claude/skills/release/SKILL.md`. Skill jde s repem.
- **Build number formát**: sekvenční per verze. Skill najde nejvyšší existující tag `v<NEW>.*` a zvedne build o 1. Pro „only build" zůstává verze, build se inkrementuje.
- **Skill scope**: jen lokálně — bump + commit + tag. Žádný `git push`, žádný deploy. Po dokončení vytiskne návod follow-up příkazů.
- **Changelog storage**: `src/data/changelog.json` — strukturovaný JSON v repu, naimportovaný do UI bundle. Skill ho updatuje při releasu (přidá nový záznam nahoru). Diffovatelný v PR, žádná DB migrace.
- **Souhrn text**: Claude transformuje `git log <last_tag>..HEAD --pretty=format:"%s%n%b"` do user-friendly bullet pointů → ukáže návrh → uživatel schválí/upraví/přidá → uloží.
- **Datum**: dnešní datum (`new Date()`) v okamžiku spuštění skillu — odpovídá vytvoření tagu.
- **Typ bumpu**: skill napřed sám **doporučí** patch/minor/major na základě analýzy commitů od posledního tagu (semantic versioning heuristika). Doporučení s odůvodněním předloží uživateli, který ho schválí nebo přepíše.

## A) Skill `/release` — `SKILL.md` obsah

### Frontmatter

```yaml
---
name: release
description: Vytvoří release BOSS — bump verze, AI souhrn změn z git logu, zápis do changelog.json, commit, git tag se sekvenčním buildem
---
```

### Tělo (instrukce pro Claude)

#### 1. Kontrola pracovního stromu

```bash
git status --porcelain
```

Pokud výstup není prázdný → **STOP** s hlášením „Pracovní strom obsahuje neuložené změny: …. Před release commitni nebo stashni." Skill skončí.

#### 2. Načíst aktuální verzi a poslední tag

```bash
node -p "require('./package.json').version"     # CURRENT_VERSION
git tag -l "v*" --sort=-version:refname | head -1   # LAST_TAG (může být prázdné)
```

#### 3. Analyzovat commity a doporučit typ bumpu

```bash
# Když existuje LAST_TAG:
git log "${LAST_TAG}..HEAD" --pretty=format:"%H%x09%s%n%b%n---"

# Když ne (první release):
git log --pretty=format:"%H%x09%s%n%b%n---"
```

Claude analyzuje výstup podle semver heuristiky:

| Rozhodovací pravidlo                              | Bump    |
| ------------------------------------------------- | ------- |
| Žádné commity od `LAST_TAG`                       | `only build` |
| Některý commit má `BREAKING CHANGE:` v body       | `major` |
| Některý subject má vykřičník (`feat!:`, `fix!:`)  | `major` |
| Existuje alespoň jeden `feat:` / `feat(...):`     | `minor` |
| Pouze `fix`, `chore`, `refactor`, `docs`, `style`, `perf`, `ci`, `build`, `test` | `patch` |

Vypsat uživateli **návrh + odůvodnění**:

```
Doporučený bump: minor

Důvody (z 9 commitů od v0.1.0):
- 4 nové funkce (feat:)
  · Šablony přeprav
  · Storno potvrzených objednávek
  · Editace potvrzených objednávek
  · PDF dialog pro výběr jazyka
- Žádné breaking changes (žádný BREAKING CHANGE / `!:`)
- Zbytek: 3 fix, 2 ui polish

Cílová verze: 0.1.0 → 0.2.0
Build number: 1
```

#### 4. Zeptat se uživatele (AskUserQuestion)

4 volby s **doporučenou jako první** a tagem „(Recommended — z analýzy)":

- Doporučený bump (např. `minor`) — `(Recommended — z analýzy)`
- `patch`
- `major`
- `only build`

Pro „only build" nebo manuální override se znovu spočítá `NEW_VERSION`. Pokud uživatel zvolí jinou variantu než doporučení, skill nepokárá ani neopakuje analýzu — jen pokračuje s tou volbou.

#### 5. Spočítat build number

```bash
git tag -l "v${NEW_VERSION}.*" --sort=-version:refname | head -1
```

- Žádný výstup → `BUILD = 1`
- Jinak parsovat poslední číslo za poslední tečkou: `BUILD = max + 1`

Sanity check: tag `v${NEW_VERSION}.${BUILD}` ještě neexistuje, jinak STOP.

#### 6. Vygenerovat návrh změn z git logu

Reusovat výstup `git log` z kroku 3 (analýza pro bump). Claude transformuje commit subjects/bodies do user-friendly bullet points v češtině:

- Sloučit související commity (UI polish + 3 fix commity → jeden bullet „Vylepšení vzhledu kontextového menu")
- Vyhodit interní úklid (chore:, refactor: bez user-visible dopadu, bumpy verzí)
- Zaměřit se na **co uživatel uvidí**, ne **jak je to implementované**
- Žádný technický žargon

Příklad transformace:

```
Commit:        "feat(templates): list, new, and edit pages"
                "feat(orders): save-as-template menu item + template picker"
Bullet point:  "Přidána sekce Šablony — vytvoření, editace a použití opakovaných objednávek"
```

#### 7. Zobrazit návrh + dovolit úpravy

Vytisknout návrh bullet pointů. Zeptat se uživatele:

- „OK, zapsat takto" → pokračovat s touto verzí
- „Chci změnit" → uživatel poskytne edited verzi (volný text), Claude použije

(`AskUserQuestion` se 2 volbami nebo přímo otázka „Chceš návrh upravit?" + možnost free-form odpovědi).

#### 8. Updatovat `package.json` (jen pro patch/minor/major)

Edit `package.json` `"version"` na `NEW_VERSION`. Pro „only build" tento krok přeskočit.

#### 9. Updatovat `src/data/changelog.json`

Načíst existing JSON (nebo vytvořit prázdný `{ "versions": [] }` pokud neexistuje). Přidat **na začátek** pole `versions` nový záznam:

```json
{
  "version": "1.4.12",
  "build": 34,
  "releasedAt": "2026-07-24",
  "changes": [
    "Bullet point 1",
    "Bullet point 2"
  ]
}
```

`releasedAt` formátované ISO `YYYY-MM-DD` (lze v UI parsovat na lokalizované zobrazení). Skill používá dnešní datum (`new Date()`).

#### 10. Commit

```bash
git add package.json src/data/changelog.json
git commit -m "v${NEW_VERSION}"
```

Pro „only build" commit vypadá stejně, ale obsahuje jen `src/data/changelog.json` (bez bumpu package.json):

```bash
git add src/data/changelog.json
git commit -m "v${NEW_VERSION}.${BUILD}"
```

(Pro „only build" přidávám build do commit message, abych odlišil od minulého commitu se stejnou verzí.)

#### 11. Tag

```bash
git tag "v${NEW_VERSION}.${BUILD}"
```

#### 12. Závěrečná zpráva

```
Release v${NEW_VERSION}.${BUILD} připraven lokálně.

Další kroky (uživatel rozhodne kdy):
  git push
  git push origin v${NEW_VERSION}.${BUILD}
  ./deploy/deploy.sh test
  ./deploy/deploy.sh prod
```

### Bezpečnostní pravidla v skillu (explicitně zmíněné)

- Skill **NIKDY** nespouští `git push`, push tagů, ani SSH/deploy. Po lokálním commitu+tagu skončí a vytiskne follow-up příkazy.
- Pokud cokoli selže (dirty tree, kolize tagu, chybí changelog.json struktura), skill zastaví bez částečných stavů.
- Skill je čistě česky (instrukce, hlášky uživateli).

## B) UI změny — changelog v profile menu

### B1. JSON struktura

`/Users/jiri/Projects/beer-order-sheet-system/src/data/changelog.json`:

```json
{
  "versions": [
    {
      "version": "0.1.0",
      "build": 1,
      "releasedAt": "2026-04-28",
      "changes": [
        "První release BOSS"
      ]
    }
  ]
}
```

První záznam vytvoří uživatel ručně před prvním releasem (nebo skill při prvním spuštění bude umět načíst i prázdný/neexistující soubor a vytvořit počáteční).

### B2. TS typy + import helper

`/Users/jiri/Projects/beer-order-sheet-system/src/lib/changelog.ts`:

```ts
import changelog from '@/data/changelog.json';

export interface ChangelogEntry {
  version: string;
  build: number;
  releasedAt: string;       // YYYY-MM-DD
  changes: string[];
}

export function getAllVersions(): ChangelogEntry[] {
  return changelog.versions as ChangelogEntry[];
}

export function getLatestVersion(): ChangelogEntry | null {
  const versions = getAllVersions();
  return versions[0] ?? null;
}

export function formatVersionLabel(entry: ChangelogEntry, locale: string): string {
  // 1.4.12(34) 24.7.2026 (cs/en intl date)
  const [y, m, d] = entry.releasedAt.split('-');
  const date = new Intl.DateTimeFormat(locale, {
    day: 'numeric',
    month: 'numeric',
    year: 'numeric',
  }).format(new Date(Number(y), Number(m) - 1, Number(d)));
  return `${entry.version}(${entry.build}) ${date}`;
}
```

### B3. Modal komponenta

`/Users/jiri/Projects/beer-order-sheet-system/src/components/layout/changelog-modal.tsx`:

- Použije existing `<AlertDialog>` z `@/components/ui/alert-dialog.tsx`
- `<AlertDialogContent className="max-w-2xl">` (širší pro čitelnost)
- Title: `t('changelogTitle')` — „Historie verzí" / „Version history" / „Versionshistorie"
- Scrollable body (`max-h-[70vh] overflow-auto`):
  - Pro každou verzi sekce:
    - Header `<h3>{formatVersionLabel(entry, locale)}</h3>` (žlutě tučné, sticky uvnitř každé sekce není potřeba)
    - `<ul>` s bullet pointy `entry.changes`
- Klávesnice + escape close pomocí `AlertDialog` defaultního chování
- Žádný cancel button — jen close X / klik mimo / Escape

### B4. Tlačítko v profile menu

`/Users/jiri/Projects/beer-order-sheet-system/src/components/layout/profile-menu.tsx`:

Upravit existing menu — přidat položku **nad** „Odhlásit se":

```tsx
{latestVersion && (
  <DropdownMenuItem onClick={() => setChangelogOpen(true)}>
    <MdHistory size={16} />
    {tn('versionLabel', { label: formatVersionLabel(latestVersion, locale) })}
  </DropdownMenuItem>
)}
<DropdownMenuSeparator />
{/* Existing logout item */}
```

i18n key `versionLabel`: `Verze {label}` / `Version {label}` / `Version {label}`.

Render `<ChangelogModal>` v profile-menu na konci.

### B5. i18n klíče (cs/en/de)

Pod nový namespace `changelog`:

- `title` — „Historie verzí" / „Version history" / „Versionshistorie"
- `noEntries` — „Zatím žádné verze." / „No versions yet." / „Noch keine Versionen."

Pod existující `nav` (nebo `profile`) namespace:

- `versionLabel` — „Verze {label}" / „Version {label}" / „Version {label}"

### B6. Build-footer souhrn

Build-footer dále zobrazuje **deploy timestamp** + commit SHA (nezměněno — ukazuje JINÉ informace než release verze). Čili:

- Build-footer (vpravo dole, fixed): `D.M.YYYY HH:MM · ABC123` — kdy byla tato instance nasazena
- Profile menu („Verze X.Y.Z(N) DD.M.YYYY"): kdy byla **vydána** poslední verze v changelogu

Ujasnit v komentáři kódu, aby bylo jasné, že to nejsou totožné údaje.

## Implementační kroky (commit-by-commit)

### Commit 1 — UI changelog infrastruktura (bez release skillu, bez dat)

- Vytvořit `src/data/changelog.json` s jedním seed záznamem `{"version":"0.1.0","build":1,"releasedAt":"<dnes>","changes":["První release BOSS"]}`
- `src/lib/changelog.ts` — types + helpers
- `src/components/layout/changelog-modal.tsx` — modal komponent
- `src/components/layout/profile-menu.tsx` — přidat položku + render modal
- i18n cs/en/de — namespace `changelog` + klíč `nav.versionLabel`

`feat(ui): version changelog modal in profile menu`

### Commit 2 — `/release` skill

- Vytvořit `.claude/skills/release/SKILL.md` s obsahem výše

`chore: add /release skill`

### Commit 3 (volitelný) — vyzkoušet skill

Pokud chceš provést první „ostrou" release k otestování (jen lokálně, bez push), spustit `/release` → patch → vznikne `v0.1.1` commit + tag `v0.1.1.1` se souhrnem změn od `v0.1.0` (= seed).

## Critical files

**Nové:**

- `/Users/jiri/Projects/beer-order-sheet-system/.claude/skills/release/SKILL.md` (skill)
- `/Users/jiri/Projects/beer-order-sheet-system/src/data/changelog.json` (data)
- `/Users/jiri/Projects/beer-order-sheet-system/src/lib/changelog.ts` (helper)
- `/Users/jiri/Projects/beer-order-sheet-system/src/components/layout/changelog-modal.tsx` (modal)

**Upravené:**

- `/Users/jiri/Projects/beer-order-sheet-system/src/components/layout/profile-menu.tsx` (přidat položku + modal)
- `/Users/jiri/Projects/beer-order-sheet-system/messages/cs.json` (changelog namespace)
- `/Users/jiri/Projects/beer-order-sheet-system/messages/en.json` (changelog namespace)
- `/Users/jiri/Projects/beer-order-sheet-system/messages/de.json` (changelog namespace)

## Reused utilities

- `<AlertDialog>` z `src/components/ui/alert-dialog.tsx` — vzor používaný i v `PdfLanguageDialog`, `SaveAsTemplateDialog`
- Existing `<DropdownMenu>` z `src/components/ui/dropdown-menu.tsx` v profile-menu
- `useTranslations` z `next-intl` — i18n
- `react-icons/md` `MdHistory` ikona
- `formatVersionLabel` (nový helper) — používá `Intl.DateTimeFormat` (locale-aware)
- Skill format z `~/.claude/skills/commit/SKILL.md` — frontmatter konvence

## Verification

### UI (Commit 1)

1. Spustit `pnpm dev`, otevřít aplikaci, kliknout na profile (vpravo nahoře)
2. Vidět novou položku „Verze 0.1.0(1) <dnes>" nad „Odhlásit se"
3. Kliknout — otevře se modal s nadpisem „Historie verzí" a jednou položkou seed `0.1.0(1)` + bullet „První release BOSS"
4. Zavřít přes Escape, klik mimo, klik na profile menu znovu → modal zase otevírá

### Skill (Commit 2 + e2e)

1. Pre-check: `git status` čistý
2. Spustit `/release` → vyber „patch"
3. Skill ukáže návrh bullet pointů — zkontrolovat že odráží reálné commity od v0.1.0 (seed). První iterace `Pp` může mít prázdný diff (žádné commity od seed) — skill by měl zvládnout tuto edge.
4. Schválit
5. Ověřit:
   - `cat package.json | grep version` → `"version": "0.1.1"`
   - `cat src/data/changelog.json` → nový záznam nahoře
   - `git log --oneline -1` → `v0.1.1`
   - `git tag` → `v0.1.1.1`
6. Aplikaci znovu načíst — profile menu ukazuje `Verze 0.1.1(1) <dnes>`. Modal má 2 verze (0.1.1 nahoře, 0.1.0 dole).

### Negativní test skillu

- Modify libovolný soubor bez commitu → spustit `/release` → skill abort s hlášením o dirty tree
- Spustit `/release` → „only build" když ještě neexistuje žádný tag → skill vytvoří `v0.1.0.X` (X = max+1) bez bumpu package.json a bez commitu změny verze (commit jen pro changelog.json)

## Order of commits

1. `feat(ui): version changelog modal in profile menu`
2. `chore: add /release skill`

(Volitelný 3. = test release commit, vznikne při prvním spuštění skillu — to už řídí skill sám.)
