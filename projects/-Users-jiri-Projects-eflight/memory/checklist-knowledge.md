# Checklist rezervace — znalosti

## Přehled

Checklist slouží k předletové kontrole všech náležitostí pro každý leg (úsek) rezervace. Každý leg má sekce: **DEPARTURE**, **ARRIVAL**, a volitelně **ALTERNATE1-3**.

## Hlavní komponenty (cesty)

```
src/Admin/Scheduling/screen/Calendar/ReservationForm/ChildEventForm/Checklist/ChecklistTable/
├── index.tsx              — hlavní komponenta
├── TabButton.tsx          — tlačítko záložky s BadgeView
├── TabPanel.tsx           — panel s obsahem
├── ConfirmButton.tsx      — tlačítka potvrzení (Confirm, N/CF, N/RQ, Req, Draft)
├── Tabs/
│   └── ServiceTab.tsx     — tab pro konfigurabilní služby
└── utils/
    ├── index.ts           — getChecklistTabData, getFlagColor
    ├── getChecklistKeys.ts — filtrování viditelných klíčů
    ├── createEventFlagForChecklistTab.ts — logika flagů
    ├── FLAG.ts            — WARNING_FLAG, VALID_FLAG, ERROR_FLAG
    ├── getChecklistTabName.ts — mapování klíčů na UI názvy
    └── isServiceNotRequired.ts — FLAG_LIMITS logika
```

**Další důležité soubory:**
- `src/Admin/Scheduling/model/SchedulingTypes.ts` — typy ChecklistKey, ChecklistPermanentKey, ChecklistConfigurableKey
- `src/Admin/Scheduling/Datasources/checklist.ts` — logika potvrzování
- `src/hooks/data/checklist.ts` — fetchReservationChecklistKeys()
- `node_modules/@eflight/shared/dist/scheduling/types/index.d.ts` — Checklist, Confirmation, LegChecklist typy

## Typy checklistových položek (ChecklistKey)

### PERMANENT (vždy viditelné):
- `generalDispatchNotes` → "Disp Nts"
- `adCategorization` → "AD CAT" (jen pro určitá letadla)
- `wx` → "WX" (počasí)
- `notam` → "Notam"

### CONFIGURABLE (podle nastavení letiště):
- `slotPprRequired` → "Slot / PPR"
- `handling` → "Handling"
- `immigrationCustomsAvailable` → "Imm/Cus" (jen mezinárodní lety)
- `fuelAvgasAvailable` → "Fuel AVGAS" (jen AVGAS letadla)
- `fuelJetAvailable` → "Fuel Jet" (jen JET letadla)
- `gendecRequired` → "Gendec"
- `petsPermitRequired` → "Pets Permit" (jen když jsou zvířata)
- `boardToBoardService` → "Brd2Brd"
- `vipTerminal` → "Lounge"

### EXTRA (speciální):
- `flightPlan` → "FPL" (jen departure)
- `countryPermit` → "Permit" (podmíněno EU/non-EU logikou)
- `airportService` → "ARPT" (jen když handling on_request)
- `catering` → "Catering" (jen departure)
- `taxi` → "Taxi"
- `avinode` → "Avinode"

## Stavy (Confirmation Status)

| Status | UI Text | Barva | Popis |
|--------|---------|-------|-------|
| `confirmed` | CFM | zelená (success) | Potvrzeno |
| `not_confirmed` | N/CF | červená (danger) | Nepotvrzeno |
| `requested` | Req | oranžová (warning) | Požádáno |
| `not_required` | N/RQ | šedá (secondary) | Není vyžadováno |
| `drafted` | DRF | oranžová (warning) | Rozpracováno |
| `automatic_valid` | AVBL | zelená | Automaticky platné |
| `automatic_not_available` | N/AVBL | — | Automaticky nedostupné |

## Pořadí vykreslování

```
generalDispatchNotes, adCategorization, wx, notam, flightPlan,
slotPprRequired, handling, airportService, immigrationCustomsAvailable,
fuelAvgasAvailable, fuelJetAvailable, gendecRequired, taxi, catering,
petsPermitRequired, boardToBoardService, vipTerminal
```

## Detail položky (po kliknutí)

Většina položek zobrazí formulář s:
- **Time** (DateTimePickerUTC) + "Set default time"
- **Number** (textbox + NIL tlačítko)
- **Provider** dropdown (pro handling, slot/ppr)
- **Note** textarea
- Akční tlačítka: **Confirm** | **Not Confirmed** | **Not Required** | **Requested**
- Badge s posledním stavem (datum UTC + uživatel)

Speciální: **FPL** má tabulku palivových hladin, Flight Rules, RocketRoute integraci; **WX** má METAR/TAF data.

## FLAG_LIMITS (kdy warning/error)

```
flightPlan:         warning 24h, error 12h
catering:           warning 48h, error 24h
gendecRequired:     warning 48h, error 24h
fuelAvgasAvailable: warning 120h (5d), error 24h
fuelJetAvailable:   warning 120h (5d), error 24h
```

## Flag logika — SLOT/PPR (vzorová)

Soubor: `createEventFlagForChecklistTab.ts`

| Stav potvrzení | Záložka | Flag |
|---|---|---|
| **null** (žádná akce) | zobrazená dle requestPeriodDays | error: pokud zbývá méně času než requestPeriodDays, NEBO requestPeriodDays není nastaveno, NEBO EarlySlotWaitingList |
| **confirmed** | zobrazená | valid |
| **not_confirmed** | zobrazená | error |
| **requested** | zobrazená | EarlySlotWaitingList + requestPeriodDays + requested před datem → warning→error. Jinak → REQ_LOGIC |
| **not_required** | minimalizovaná | valid |

**REQ_LOGIC** (`REQ_LOGIC.ts`) — requested stav bez EarlySlotWaitingList:
- >360h před letem: warning → error po 48h od requestu
- >168h před letem: warning → error po 24h od requestu
- >72h před letem: warning → error po 6h od requestu
- >24h před letem: warning → error po 4h od requestu
- ≤24h před letem: okamžitý error

**Speciální logika LKPR:** noční lety (2200-0600LT) → error 24h před letem.

## Flag logika — COUNTRY PERMIT

Soubor: `createEventFlagForChecklistTab.ts` (řádky 246-307)

| Stav potvrzení | Flag |
|---|---|
| **null** (žádná akce) | valid → error při permitRequestPeriodDays před letem (default **7 dnů**, z country) |
| **confirmed** | error pokud se čas odletu/příletu změní o víc než permitToleranceHours (default **2h**, z country), jinak valid |
| **not_confirmed** | error |
| **requested** | REQ_LOGIC |

**Rozdíly oproti SLOT/PPR:**
- Timing z country modelu (`permitRequestPeriodDays`, `permitToleranceHours`), ne z airport
- Confirmed má tolerance check (porovnání serviceTime vs aktuální eventTime)
- Requested → čistě REQ_LOGIC (žádná EarlySlotWaitingList)

## Screenshoty

Viz `memory/screenshots/` — soubory checklist-*.png
