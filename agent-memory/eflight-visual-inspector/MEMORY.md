# eFlight Visual Inspector Memory

## Login
- URL: http://localhost:3000/ops
- Credentials: jiri@d4works.cz / testA380
- Login is handled automatically when navigating (session-based, no explicit login form usually needed)

## Key Pages
- Scheduling calendar: http://localhost:3000/ops (default)
- Airports: http://localhost:3000/ops/airports/
- Country Notes: http://localhost:3000/ops/airports/country-notes
- Airport detail: http://localhost:3000/ops/airport/{uuid}

## Airports Page Structure
- Toolbar row: Search textbox (pre-filled with country prefix e.g. "LK"), Country dropdown, Tab links (Airports / Country Notes), Show Closed button
- Airports tab: Map + airport list grid (ICAO code buttons + named links)
- Country Notes tab: Country-specific notes form
- Tabs are URL-based: /ops/airports/ = Airports, /ops/airports/country-notes = Country Notes
- Default country: Czech Republic (LK prefix)

## Scheduling Calendar — Reservation Modal
- Otevření: kliknutí na let (vis-item vis-range) na timeline — koordináty závisí na zobrazené oblasti
- Klíčová CSS třída pro scrollování: `.reservation-parts-navigator__scroller-content`
- Záložky modalu: CHAT, ACTIVE SCHEDULE, SERVICES, PAX, CUST. BRIEF, FLIGHT ORDER
- Checklist sekce jsou na konci ACTIVE SCHEDULE záložky (scrollovat dolů)
- Každý leg má sekce: DEPARTURE, ARRIVAL, a každý ALTERNATE

## Checklist Struktura
- Každá sekce (DEPARTURE / ARRIVAL / ALTERNATE) má header s:
  - Název sekce + ICAO kód (např. "EDLN DEPARTURE")
  - Ikonka upozornění "!" pokud jsou problémy
  - "ADD OPS NOTE" tlačítko (link, modrý text)
  - "TO AIRPORT" odkaz vpravo (link na /ops/airport/{uuid}/)
- Checklistové položky jsou tlačítka s názvem a stavem

## Checklistové Položky — Typy a Stavy
### Typy položek:
- DISP NTS — dispatch notes (zobrazuje text poznámek)
- NOTAM — NOTAM confirmace
- FPL — flight plan confirmace (s tabulkou FL hladin, RocketRoute link)
- HANDLING — handling service confirmace (Provider dropdown)
- FUEL JET — fuel confirmace (Provider dropdown)
- GENDEC — general declaration (Departure + Arrival)
- SLOT / PPR — slot/PPR confirmace (Provider dropdown)
- WX — počasí (TAF, METAR, RVR/MDH, Windy.com link)
- TAXI, CATERING, BRD2BRD, LOUNGE — bez speciálních polí

### Stavy položek (badge na tlačítku):
- CFM — potvrzeno (zelený badge)
- CFM HH:MM — potvrzeno s časem (zelený badge)
- N/CF — Not Confirmed (červený/růžový badge)
- Req HH:MM — Requested s časem (žlutý/oranžový badge)
- Req — Requested bez času (žlutý/oranžový badge)
- [bez textu / šedé] — neaktivní/nevyplněno

### Akce v detailu položky:
- Confirm (bílý/výchozí)
- Not Confirmed (červený obrys)
- Not Required (šedý/bílý)
- Requested (žlutý/oranžový obrys)
- Badge s datem UTC + jménem posledního uživatele

### FPL položka — speciální obsah:
- FPL Service Confirmation: Time, Number (+ NIL), tabulka FL hladin
- Flight Rules: IFR/VFR/IFR-VFR/VFR-IFR
- Operation: Commercial/General/Training/Other
- FPL Status, Flight Rules, OPS, Alternate, EOBT, ETA, Block Fuel
- Tlačítka: "View in RocketRoute", "Choose Different FPL", "Crossfill all"
- WX validation banner (zelený ✓ OK nebo červený)
- Badge: confirmed (by selecting FPL) + datum + uživatel + případně error

### WX položka — speciální obsah:
- Link: "Windy.com - {ICAO}"
- Tlačítko "Load METAR"
- TAF data s ✓ indikátorem
- RVR + MDH textboxy
- WX OK/FAIL banner s vysvětlením
- Jediná akce: Confirm

### HANDLING/SLOT/PPR položky — speciální obsah:
- Provider dropdown (předvyplněno z databáze letiště)
- Kontaktní link (email + telefon)

### PERMIT položka — speciální obsah:
- Readonly sekce "COUNTRY NOTES ({Název země})" — zobrazuje country notes s formátováním (tučně, barevný text)
- Pokud země nemá notes, sekce Country Notes se nezobrazuje (nebo je prázdná)
- Formulář "PERMIT SERVICE CONFIRMATION": Time (datum + čas pole) + "Set default time" tlačítko, Number (prázdné pole) + NIL tlačítko, Note (textarea)
- Time obsahuje datum letu (DEPARTURE = datum odletu, ARRIVAL = datum příletu)
- Akce: Confirm, Not Confirmed (červený obrys), Not Required, Requested (žlutý obrys)
- PERMIT se zobrazuje v DEPARTURE i ARRIVAL sekci každého legu
- Pozice v DEPARTURE: za FPL, před SLOT/PPR
- Pozice v ARRIVAL: za NOTAM, před dalšími položkami (liší se dle leg konfigurace)

## Screenshots Index
- See screenshots/ subfolder for visual inspection records
