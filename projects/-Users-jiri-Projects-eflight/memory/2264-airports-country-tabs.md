# (#2264) Přidání záložek Airports / Country Notes na stránku letišť

## Kontext

Stránka `/ops/airports/` zobrazuje seznam letišť vybrané země s mapou. Nastavení země (permit, EU flagy, poznámky) je na samostatné stránce `/ops/countries/{id}`. Cílem je přidat na stránku letišť dvě záložky — "Airports" (stávající funkcionalita) a "Country Notes" (formulář s nastavením země), aby uživatel nemusel přecházet na jinou stránku.

## Plán implementace

### 1. Upravit `CountryDetail` — přidat prop `showBackLink` ✅

**Soubor:** `src/Admin/Countries/screen/CountryDetail.tsx`

- Přidán optional prop `showBackLink?: boolean` (default `true`)
- Podmíněně se zobrazuje `<LinkA to="/countries">Back to list</LinkA>` jen pokud `showBackLink !== false`
- Stávající `CountryDetailScreen` ho volá bez prop → chování se nezměnilo

### 2. Upravit `AirportListScreen` — přidat záložky a napojení na country ✅

**Soubor:** `src/Admin/screens/Airports/AirportListScreen/AirportListScreen.tsx`

- URL-based routing: `/ops/airports/` (default) a `/ops/airports/country-notes`
- `useMatch` pro detekci aktivní záložky místo state
- `countryId` state — UUID země načtené z DB přes `getCachedCountry(icaoPrefix)`
- Bootstrap `nav nav-pills` záložky jako `LinkA` vedle dropdownu
- Nested `<Routes>` pro obsah záložek
- Přepnutí země zachová aktivní záložku (díky URL)

### 3. Layout záložek ✅

```
[Search box] [Country dropdown] [Airports | Country Notes] [Show Closed*]
```
*Show Closed jen pokud je aktivní tab Airports

### 4. Přidat readonly country info do hlavičky stránky Airports

Zobrazit klíčové boolean flagy země přímo v toolbaru/hlavičce:
- Genedec required
- Is EU
- Permit EU
- Permit 3rd Country

Zobrazují se readonly (ne editovatelné) — slouží jako rychlý přehled o zemi.

## Zbývá

- [ ] Implementace readonly country info v hlavičce (#4)
