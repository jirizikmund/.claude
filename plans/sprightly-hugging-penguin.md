# (#1057) Nový checklist tab "Permit" pro country permits

## Kontext

Potřebujeme přidat novou záložku "Permit" do checklistu rezervace, která bude sloužit ke kontrole country permits. Tab bude kombinovat:
1. **Formulář jako SLOT/PPR** — Time, Number, Note + akční tlačítka (Confirm/N-CF/N-RQ/Req)
2. **Readonly country notes** — zobrazení poznámek z country modelu (formát jako DISP NTS)

Podmínky zobrazení budou doplněny později (EU/non-EU, typ letu apod.). Zatím zobrazovat vždy.
FLAG_LIMITS budou doplněny později.

## Implementační kroky

### 1. Přidat `countryPermit` do sdíleného typu `Checklist`
**Soubor:** `node_modules/@eflight/shared/src/scheduling/types/index.ts` (řádek 131)

Přidat nový klíč do typu `Checklist`:
```typescript
// Extra
taxi?: Confirmation[];
catering?: Confirmation[];
flightPlan?: Confirmation[];
airportService?: Confirmation[];
avinode?: Confirmation[];
countryPermit?: Confirmation[];  // NOVÉ
```

### 2. Registrovat klíč v SchedulingTypes
**Soubor:** `src/Admin/Scheduling/model/SchedulingTypes.ts`

- Přidat `'countryPermit'` do `ChecklistExtraKey` Pick (řádek 226-229):
  ```typescript
  export type ChecklistExtraKey = keyof Pick<
      Checklist,
      'taxi' | 'catering' | 'flightPlan' | 'airportService' | 'avinode' | 'countryPermit'
  >;
  ```
- Přidat do `extraKeys` Record (řádek 248-254):
  ```typescript
  const extraKeys: Record<ChecklistExtraKey, null> = {
      taxi: null,
      catering: null,
      flightPlan: null,
      airportService: null,
      avinode: null,
      countryPermit: null,
  };
  ```
- Přidat do `checklistKeyOrdering` za `'flightPlan'` (řádek 256-274):
  ```typescript
  'flightPlan',
  'countryPermit',  // NOVÉ - za FPL
  'slotPprRequired',
  ```

### 3. Přidat tab name
**Soubor:** `src/Admin/Scheduling/screen/Calendar/ReservationForm/ChildEventForm/Checklist/ChecklistTable/utils/getChecklistTabName.ts`

Přidat mapování:
```typescript
countryPermit: 'Permit',
```

### 4. Přidat do getChecklistKeys — logika zobrazení
**Soubor:** `src/Admin/Scheduling/screen/Calendar/ReservationForm/ChildEventForm/Checklist/ChecklistTable/utils/getChecklistKeys.ts`

V `getChecklistConfigurableAndExtraKeys` přidat `'countryPermit'` — pro obě direction (departure i arrival). Přidat za přidání `'flightPlan'` (departure) i mimo něj:
```typescript
// Permit tab - zatím vždy, podmínky budou doplněny později
configurableAndExtraKeys.push('countryPermit');
```

### 5. Přidat default time
**Soubor:** `src/Admin/Scheduling/screen/Calendar/ReservationForm/ChildEventForm/Checklist/ChecklistTable/utils/getDefaultChecklistTime.ts`

Přidat mapování:
```typescript
countryPermit: departureArrivalTime,
```

### 6. Vytvořit PermitTab komponentu
**Nový soubor:** `src/Admin/Scheduling/screen/Calendar/ReservationForm/ChildEventForm/Checklist/ChecklistTable/Tabs/PermitTab.tsx`

Kombinace ServiceTab logiky + readonly country notes:
- Použít existující ServiceTab jako základ (Time, Number, Note, ConfirmButton)
- Nad formulářem zobrazit readonly country notes pomocí `RichTextEditorHtmlOutput` (pokud existují)
- Načíst country data pomocí `getCachedCountry(icao)` — ICAO se určí podle direction (departure = `childEvent.location`, arrival = `childEvent.locationEnd`)
- Zobrazit country notes ve formátu `CustomPage` (stejně jako DISP NTS)

### 7. Registrovat PermitTab v ChecklistTable
**Soubor:** `src/Admin/Scheduling/screen/Calendar/ReservationForm/ChildEventForm/Checklist/ChecklistTable/index.tsx`

V renderu místo defaultního `ServiceTab` pro klíč `countryPermit` vykreslit `PermitTab`:
- V mapování `checklistConfigurableAndExtraKeys` odfiltrovat `'countryPermit'`
- Přidat dedicovaný `<TabPanel value="countryPermit">` s `<PermitTab .../>` (analogicky k ostatním speciálním tabům)

### 8. Flag logika (placeholder)
**Soubor:** `src/Admin/Scheduling/screen/Calendar/ReservationForm/ChildEventForm/Checklist/ChecklistTable/utils/createEventFlagForChecklistTab.ts`

Zatím bude `countryPermit` procházet defaultní logikou na konci funkce:
- Nepotvrzeno → `ERROR_FLAG` ("Confirmation required")
- Potvrzeno → `VALID_FLAG`
- Requested → `WARNING_FLAG`

(FLAG_LIMITS budou doplněny později dle požadavků.)

### 9. isServiceNotRequired (placeholder)
**Soubor:** `src/Admin/Scheduling/screen/Calendar/ReservationForm/ChildEventForm/Checklist/ChecklistTable/utils/isServiceNotRequired.ts`

Zatím žádná speciální logika — `countryPermit` propadne na `return false` (vždy required/zobrazený).

### 10. Requested logika
**Soubor:** `src/Admin/Scheduling/screen/Calendar/ReservationForm/ChildEventForm/Checklist/ChecklistTable/utils/createEventFlagForChecklistTab.ts`

Přidat `'countryPermit'` do bloku řádek 273-281 kde se řeší requested logika pro slotPprRequired, handling atd.:
```typescript
if (
    checklistKey === 'slotPprRequired' ||
    checklistKey === 'countryPermit' ||  // NOVÉ
    ...
```

## Klíčové soubory

| Soubor | Změna |
|--------|-------|
| `node_modules/@eflight/shared/src/scheduling/types/index.ts` | Přidat `countryPermit` do Checklist typu |
| `src/Admin/Scheduling/model/SchedulingTypes.ts` | ExtraKey, extraKeys, ordering |
| `ChecklistTable/utils/getChecklistTabName.ts` | Mapování 'Permit' |
| `ChecklistTable/utils/getChecklistKeys.ts` | Logika zobrazení |
| `ChecklistTable/utils/getDefaultChecklistTime.ts` | Default time |
| `ChecklistTable/Tabs/PermitTab.tsx` | **NOVÝ** — komponenta tabu |
| `ChecklistTable/index.tsx` | Registrace PermitTab |
| `ChecklistTable/utils/createEventFlagForChecklistTab.ts` | Requested logika |
| `src/Admin/Countries/Datasources/Countries.ts` | Reuse `getCachedCountry()` |
| `src/components/RichTextEditor/RichTextEditorHtmlOutput.tsx` | Reuse pro readonly country notes |

## Ověření

1. Spustit dev server (`pnpm dev`)
2. Visual inspector: otevřít scheduling, kliknout na rezervaci → ověřit že se zobrazí "Permit" tab v DEPARTURE i ARRIVAL sekcích
3. Kliknout na Permit tab → ověřit:
   - Zobrazují se readonly country notes (pokud země je má)
   - Formulář Time/Number/Note je funkční
   - Akční tlačítka fungují (Confirm, N/CF, N/RQ, Req)
4. Badge se správně mění podle stavu
