# (#2551) Custom filter - řazení resources (reorder)

## Context

V scheduling kalendáři (/opd) mají custom filtry seznam `resourceIds`, ale uživatel nemůže měnit jejich pořadí. Pořadí se ukládá v `filterData.resourceIds` jako pole stringů a je zachováno přes JSON serialize/deserialize. Potřebujeme:
1. UI pro přeřazení resources v rámci filtru
2. Respektování tohoto pořadí v kalendáři při zobrazení

## Plán implementace

### 1. Nová komponenta `ReorderResourcesDialog`

**Nový soubor**: `src/Admin/Scheduling/screen/ReorderResourcesDialog.tsx`

- Modal dialog (size `large`) s drag-and-drop seznamem vybraných resources
- Použít existující pattern z `AircraftWeightProfileUpdate.tsx`:
  - `DndContext` + `closestCenter` + `restrictToVerticalAxis` + `restrictToParentElement`
  - `SortableContext` + `useSortable` per item
  - `CSS.Transform.toString(transform)` pro animace
  - Drag handle tlačítko s `RiDraggable` ikonou z `@remixicon/react`
- Každý řádek zobrazí: `[⋮⋮ drag handle] [registrace/název] [typ/subtitle]`
- Přeložit resourceId → název pomocí `useCalendarResources().allResources`
- Props: `resourceIds: string[]`, `onSave: (reorderedIds: string[]) => void`, `onClose: () => void`
- Interní stav: lokální kopie pole, po drag-end přeřadit pomocí `arrayMove` z `@dnd-kit/sortable`

### 2. Tlačítko "reorder" v `CustomFilterSelector.tsx`

**Soubor**: `src/Admin/Scheduling/screen/CustomFilterSelector.tsx`

- Přidat tlačítko `reorder` (size `sm`, variant `outline-primary`) do každého řádku filtru, napravo od spaceru za multiselectem
- Zobrazit vždy (ne jen v edit mode) — reorder je samostatná akce
- Po kliknutí otevřít `ReorderResourcesDialog` s aktuálními `resourceIds` filtru
- Po uložení v dialogu: zavolat `updateFilter` se změněným pořadím a refreshnout seznam

### 3. Řazení kalendáře podle pořadí ve filtru

**Soubor**: `src/Admin/Scheduling/Datasources/sortCalendar.ts`

- Přidat nový parametr `linesResourceIds?: string[]` do `sortCalendar` (z `CalendarFilter`)
- Na začátek funkce (za focus resource a dispatch group logiku, ale před `typesOrder`): pokud oba resources jsou v `linesResourceIds`, seřadit podle indexu v tom poli
- Resources které nejsou v `linesResourceIds` půjdou za ty co tam jsou (fallback na stávající logiku)

**Soubor**: `src/Admin/Scheduling/Datasources/getCalendar.ts`

- Předat `filter` (nebo `filter.linesResourceIds`) do volání `sortCalendar`

### 4. Shrnutí měněných souborů

| Soubor | Změna |
|--------|-------|
| `src/Admin/Scheduling/screen/ReorderResourcesDialog.tsx` | **NOVÝ** - drag-and-drop dialog |
| `src/Admin/Scheduling/screen/CustomFilterSelector.tsx` | Přidat tlačítko "reorder" + otevření dialogu |
| `src/Admin/Scheduling/Datasources/sortCalendar.ts` | Respektovat pořadí z custom filtru |

## Existující kód k znovupoužití

- `@dnd-kit` pattern: `src/Admin/AircraftPerformanceWeightProfile/components/AircraftWeightProfileUpdate.tsx`
- `Modal`: `src/components/common/Modal`
- `Button, View`: `src/components`
- `useCalendarResources()`: `src/Admin/Scheduling/Datasources/useCalendar.ts` — pro překlad ID → název
- `updateFilter()`: `src/Admin/Scheduling/Datasources/customFilters.ts`
- `useSharedFilters()`: `src/hooks/data/sharedFilters.ts`

## Ověření

1. Otevřít /opd, kliknout na "Custom filter" title → otevře se konfigurační modal
2. U filtru s vybranými resources kliknout "reorder" → otevře se dialog s přetahovatelnými položkami
3. Přetáhnout položky, uložit → modal se zavře
4. Vybrat daný custom filtr v selectu → kalendář zobrazí resources v nastaveném pořadí
5. Reload stránky → pořadí zůstane zachováno (uloženo v DB)
