# (#2264) Přidání záložek Airports / Country Notes na stránku letišť

## Kontext

Stránka `/ops/airports/` zobrazuje seznam letišť vybrané země s mapou. Nastavení země (permit, EU flagy, poznámky) je na samostatné stránce `/ops/countries/{id}`. Cílem je přidat na stránku letišť dvě záložky — "Airports" (stávající funkcionalita) a "Country Notes" (formulář s nastavením země), aby uživatel nemusel přecházet na jinou stránku.

## Plán implementace

### 1. Upravit `CountryDetail` — přidat prop `showBackLink`

**Soubor:** `src/Admin/Countries/screen/CountryDetail.tsx`

- Přidat optional prop `showBackLink?: boolean` (default `true`)
- Podmíněně zobrazit `<LinkA to="/countries">Back to list</LinkA>` (řádek 282) jen pokud `showBackLink !== false`
- Stávající `CountryDetailScreen` ho volá bez prop → chování se nezmění

### 2. Upravit `AirportListScreen` — přidat záložky a napojení na country

**Soubor:** `src/Admin/screens/Airports/AirportListScreen/AirportListScreen.tsx`

- Přidat state `activeTab: 'airports' | 'country-notes'` (default `'airports'`)
- Přidat state `countryId: string | null` — UUID země načtené z DB
- Přidat `useEffect` který při změně ICAO prefixu zavolá `getCachedCountry(icaoPrefix)` a nastaví `countryId`
- Přidat záložky (Bootstrap `nav nav-pills` inline tlačítka) vedle dropdownu v header baru
- Záložky zobrazit jen pokud existuje vybraná země (search je 2-znakový ICAO prefix odpovídající zemi v dropdownu)
- Při aktivní záložce "Airports": zobrazit stávající `AirportFilteredScreen`
- Při aktivní záložce "Country Notes": zobrazit `CountryDetail` s `id={countryId}` a `showBackLink={false}`
- Tlačítko "Show Closed" zobrazit jen při aktivní záložce "Airports"
- Při změně země resetovat záložku na "Airports"

### 3. Layout záložek

Stávající header:
```
[Search box] [Country dropdown] [Show Closed]
```

Nový header:
```
[Search box] [Country dropdown] [Airports | Country Notes] [Show Closed*]
```
*Show Closed jen pokud je aktivní tab Airports

Záložky budou Bootstrap `nav-pills` s inline stylem, konzistentní se zbytkem stránky.

## Soubory k úpravě

1. `src/Admin/Countries/screen/CountryDetail.tsx` — přidat `showBackLink` prop
2. `src/Admin/screens/Airports/AirportListScreen/AirportListScreen.tsx` — přidat tabs, country loading

## Ověření

- Playwright screenshot stránky po implementaci
- Ověřit, že záložky se zobrazí jen při vybrané zemi
- Ověřit přepínání mezi Airports a Country Notes
- Ověřit, že stávající `/ops/countries/{id}` stránka stále funguje
