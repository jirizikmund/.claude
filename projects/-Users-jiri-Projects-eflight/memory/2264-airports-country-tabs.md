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

- Přidán state `activeTab: 'airports' | 'country-notes'` (default `'airports'`)
- Přidán state `countryId: string | null` — UUID země načtené z DB
- `useEffect` při změně ICAO prefixu volá `getCachedCountry(icaoPrefix)` a nastaví `countryId`
- Bootstrap `nav nav-pills` záložky vedle dropdownu v header baru
- Záložky se zobrazí jen pokud existuje vybraná země v `icaoToCountry` mapě
- Při aktivní záložce "Airports": stávající `AirportFilteredScreen`
- Při aktivní záložce "Country Notes": `CountryDetail` s `id={countryId}` a `showBackLink={false}`
- Tlačítko "Show Closed" jen při aktivní záložce "Airports"
- Při změně země se resetuje záložka na "Airports"

### 3. Layout záložek

```
[Search box] [Country dropdown] [Airports | Country Notes] [Show Closed*]
```
*Show Closed jen pokud je aktivní tab Airports

## Zbývá

- [ ] Vizuální ověření přes Playwright
