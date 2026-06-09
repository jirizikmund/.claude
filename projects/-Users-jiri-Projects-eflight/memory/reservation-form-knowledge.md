---
name: Reservation form knowledge
description: Architektura a funkcionalita editačního formuláře rezervace ve schedulingu — sekce, crew, validace, datový model
type: project
---

## Hlavní soubory

- **Formulář:** `src/Admin/Scheduling/screen/Calendar/ReservationForm/index.tsx`
- **Leg (ChildEventForm):** `src/Admin/Scheduling/screen/Calendar/ReservationForm/ChildEventForm/index.tsx`
- **Multileg kontejner:** `src/Admin/Scheduling/screen/Calendar/ReservationForm/FlightTypeMultileg.tsx`
- **Simple flight:** `src/Admin/Scheduling/screen/Calendar/ReservationForm/FlightTypeSimple.tsx`
- **ResourcesSelector:** `src/Admin/Scheduling/screen/Calendar/ReservationForm/ResourcesSelector/ResourcesSelector.tsx`
- **ResourcesSelector index (wrapper):** `src/Admin/Scheduling/screen/Calendar/ReservationForm/ResourcesSelector/index.tsx`
- **Crew validace:** `src/Admin/Scheduling/screen/Calendar/ReservationForm/ResourcesSelector/crewComposition.ts`
- **Navigace sekcí:** `src/Admin/Scheduling/screen/Calendar/ReservationForm/ReservationPartsNavigator.tsx`
- **Typy:** `@eflight/shared/src/scheduling/types/index.ts`, `src/Admin/Scheduling/model/SchedulingTypes.ts`
- **DB konverze:** `src/Admin/Scheduling/Datasources/calendar.ts`
- **Event typy config:** `src/Admin/Scheduling/model/eventsConfig/index.ts` + `ui.ts`

## State management

- Žádný form library (ne formik, ne react-hook-form)
- Reservation objekt přichází jako prop, změny jdou přes `onReservationChange` callback
- Lokální stav přes useState, usePropLocalState (debounced)
- ChildEventForm má imperative handle přes useRef (FlightTypeMultileg drží pole až 30 refs)

## Sekce formuláře (ReservationPartsNavigator)

1. **Aircraft Timeline** — vizuální timeline (jen quotation mód)
2. **Simple Edit** — quick-edit tabulka pro multileg
3. **Quotation Calculator** — cenová kalkulace (jen quotation)
4. **Reservation data** — hlavní sekce: confirmed, isExternal, event type, owner approval, title, avinode, customer
5. **Resources** — přepínač "Different crew for each leg" + ResourcesSelector (aircraft, PIC, F/O, Persons)
6. **Time & Location** — dateFrom/dateTo, location/locationEnd, notes, files
7. **Leg tabs** (#1, #2, ...) — každý leg má: Time & Route, Crew, Load & Fuel, Checklist
8. **Duty Preview** — rest/duty time (jen multileg)

## Crew systém — dvouúrovňový

### Přepínač `diffCrewForEachEvent`
- **false (default):** Crew se nastavuje na úrovni REZERVACE — všechny legy sdílí stejnou crew
- **true:** Crew se nastavuje na každém LEGU zvlášť — reservation-level selector se deaktivuje

### Crew role (ResourceRole enum)
- `pic` — Pilot in Command
- `fo` — First Officer
- `person` — další osoba (cabin crew, pax staff apod.)
- `aircraft`, `classroom`, `flightsimulator` — ostatní resource role

### EventResource typ
```ts
{ resource: Resource, role: ResourceRole, deleted?: boolean, isFixed?: boolean }
```

### "Fixed" checkbox
- Na PIC, F/O i na každé Person zvlášť
- Toggleuje `isFixed` boolean na EventResource
- Při porovnání resources se používá klíč `${role}:${resourceId}:${isFixed ? '1' : '0'}`

### Crew composition validace
- Soubor: `crewComposition.ts` — funkce `validateCrewComposition()`
- Vstup: selectedResources, typeOfFlight, crewRoles
- Kontroluje: zda PIC a F/O odpovídají požadavkům aircraft crew composition
- Výstup: `{ isValid: true }` nebo `{ isValid: false, errorMessage }`
- Zobrazení: zelený "Valid crew composition." nebo červený "Invalid crew composition." pod selectory

### Data flow crew na legy
1. ReservationForm předá `reservation.resources` a `diffCrewForEachEvent` do FlightTypeMultileg
2. FlightTypeMultileg předá každému ChildEventForm: `diffCrewForEachEvent`, `enableResourcesSelector`, `reservationResources`
3. ChildEventResourcesSelector (index.tsx wrapper):
   - Pokud `diffCrewForEachEvent === false`: automaticky kopíruje reservation crew na leg
   - Pokud `diffCrewForEachEvent === true`: zobrazuje editovatelný crew selector
4. Změny crew na legu jdou přes `onResourcesChange` → `ON_EVENT_CHANGE({ resources })` → bubbluje nahoru

## Datový model

### Reservation
- Rozšiřuje BaseEvent (id, type, dateFrom, dateTo, title, resources, location, locationEnd...)
- Specifická pole: `events?: ChildEvent[]`, `flightType`, `diffCrewForEachEvent`, `isExternal`, `contactId`, `customer`, `ownerApproval`, `avinode`, `quotationCalculation`, `flags`, `files`, `paxData`, `cancelledLegs`, `slsCancelled`, `opsCancelled`

### ChildEvent (Leg)
- Rozšiřuje BaseEvent, přidává `reservationId`
- Letové: `flightRules`, `typeOfFlight`, `alternateAirports`, `emptyLeg`, `pets`
- Palivo: `fuelUplift`, `fuelUpliftMode` (mreq/max/mreq_safe/max_safe/automatic/manual), `fuelUpliftTankering`, `fuelUpliftPrice`, `fuelUpliftCurrency`
- Loading: `loading: { male, female, child, infant, cargo }`
- Checklist: `checklist: { departure, arrival, alternate1-3 }` — každý s Confirmation[]
- Kalkulace: `calculations: { distance_nm, locationFromTimezone, locationToTimezone }`
- Flight plan: `flightPlanData: { mreq, ebrn, eetMinutes }`, `rocketRouteId`
- Soubory: `files`, `exportToAvinode`

### DB persistence
- `reservationData` se ukládá jako JSON string v `CreateReservationInput.reservationData`
- Konverze: `reservationDataToDb()` (serialize) / `reservationDataFromDb()` (parse s Date revival)
- ChildEventy v DB mají jen `id` + `reservationId` — detailní data jsou v reservation JSONu

## Roster integrace v crew selektorech

### Soubory
- **Hook pro roster data:** `src/hooks/data/reservation.ts` — `useReservationRosters()`
- **API volání:** `src/Admin/Rostering/apiUtils.ts` — `getCrewAircraftDayRoster(date, aircraftId)`
- **Roster validace wrapper:** `src/Admin/Scheduling/screen/Calendar/ReservationForm/ResourcesSelector/index.tsx` (ChildEventResourcesSelector)

### Data flow
1. `useReservationRosters()` — pro každý den letu volá API, vrací `AircraftDayRoster[]`
2. FlightTypeMultileg — matchuje roster na datum legu (`moment(roster.date).isSame(childEvent.dateFrom, 'day')`)
3. ChildEventResourcesSelector wrapper — z rosteru extrahuje `picId` a `foId` do `rosterValidation` objektu
4. ResourcesSelector — porovnává vybraného pilota s narostovaným

### AircraftDayRoster typ (`src/Admin/Rostering/types.ts`)
```ts
{ date: string, aircraftId: string, picId: string | null, foId: string | null, contacts: AircraftDayContact[] }
```
Každý contact má `states: Array<{ type: RosterRelationType, aircraftId: string | null }>`

### RosterRelationType enum
`cpt`, `fo`, `roff`, `roff_request`, `trng`, `standby`, `poff`, `maintenance`, `owner_block`, `sales_block`, `obs`, `empty`

### "Unrostered" warning
- Komponenta `UnrostedLabelSuffix` v ResourcesSelector.tsx
- Zobrazí červený "Unrostered" button u PIC/F/O, pokud vybraný pilot ≠ narostovaný pilot
- Klik otevře modální dialog s nabídkou "Set rostered PIC/F/O" — rychlé přepnutí na správného pilota

### Dropdown chování
- Zobrazuje VŠECHNY aktivní piloty (`isActiveCrew && type === 'pilot'`), nefiltruje podle dostupnosti
- Roster info je pouze informativní (warning), ne omezující
- Formát jmen: `PŘÍJMENÍ Jméno` (příjmení uppercase)

### Zakomentované features
- `getBadgesForContact()` a `getRosterRelationLabel()` — kód pro barevné badges (ROFF, TRNG, STBY...) u pilotů v dropdownu existuje, ale je zakomentovaný

## Event typy (scheduling)

### Enum EventType (`@eflight/shared/.../types/index.ts:54`)
Letové: owner_flight, charter_flight, training_flight, rental_flight, ferry_flight, wet_lease_flight
Ostatní: maintenance_aog, training, day_off, requested_day_off, standby, travel, office, home_office, other, leg

### Viditelné typy podle resource (`eventsConfig/index.ts`)
- **aircraft:** charter, training_flight, wet_lease, rental, ferry, owner, maintenance, other
- **pilot:** training, travel, other (standby/day_off/roff zakomentováno per #2535)
- **employee:** office, home_office, day_off, requested_day_off, other
- **customer:** other
- **classroom/flightsimulator:** other, training

### Default typ při vytvoření
- aircraft → charter_flight, pilot → travel, employee → office, customer → other, classroom/sim → training
