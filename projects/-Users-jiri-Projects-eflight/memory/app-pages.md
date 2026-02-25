# Stránky aplikace eFlight

## /ops/ — Scheduling (hlavní stránka po přihlášení)

### Hlavní menu (horní lišta)
- Scheduling (`/ops/`)
- Sales (`/ops/sales`) — badge s počtem (např. 87)
- OPS (`/ops/`)
- Fleet (`/ops/flights`)
- Maintenance (`/ops/fleet`)
- Crew & Users (`/ops/contacts`)
- Documents (`/ops/controlled-documents`)
- Safety Management (`/ops/airports/`)
- Admin (`/ops/`)
- Financial (`/ops/`)

### Scheduling stránka — Ganttův diagram (timeline)
- **Filtry nahoře**: Focus selector (textbox), Custom filter (combobox s přednastavenými filtry letadel)
- **Přednastavené filtry**: Phenom 100 CAT, PC-12 NGX CAT, PC-12 NG CAT, Cirrus SR22-SR22T, All PC-12, Dispatch Green (Jets + NGX), Dispatch Blue (PC12NG + other), ATO Cirrus, AOC letouny, GREEN-Props, Phenom 100/300, PC-12 PRG, CAT AC, ATO, AOC JET
- **Ovládání timeline**: Min label size, časový rozsah (1D/3D/Week/Month), navigace (<, now, >)
- **Aktuální čas** zobrazený nad timeline

### Zdroje na timeline (levý sloupec)
1. **Letadla** — registrace + typ + zbývající hodiny do údržby + datum údržby
   - Typy: C525A, Phenom 100, PC-24, Phenom 300, PC-12/47G(PRO), PC-12/47E(NG), PC-12/47E(NGX), Socata TBM700C2, PA-46-500TP, Diamond DA40, Cirrus SR22, Cirrus SR22TN, Cirrus SR22T, SR22, SR22T, Cessna 172SP, Robinson R44
2. **Simulátory/FSTD** — FTD / FNPT II, FNTP II, FTD 2
3. **Učebny** — ATPL, Briefing, Cirrus, Classroom Ruzyně, Meeting room Ruzyně
4. **Piloti** — jméno + role "pilot"
5. **Zaměstnanci** — jméno + role "employee"

### Lety na timeline
- Zobrazeny jako bloky s ICAO kódy (odkud → kam)
- Barevné kódování, statusové ikony (✓, !, P, S, L, E, čísla)
- Údržbové bloky (MX, inspekce, čištění)
- Bloky volna pilotů (OFF)

### Spodní přepínače
- Calendar, Overview, Flightboard

### Technické detaily
- Title: "Scheduling | eFlight"
- Build info ve footeru
- React aplikace, Vite bundler
- Live reload/subscription na data
