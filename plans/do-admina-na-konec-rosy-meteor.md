# Plán: Přidat přistýlky (extra beds) do modelu pokoje

## Kontext

Původní implementace ubytovacího panelu (dokončena) zná dva typy lůžek: `1` (jednolůžko) a `2` (dvoulůžko) — pole `beds: Bed[]`. Ve skutečnosti některé pokoje mají i **přistýlku** (rollaway / přídavné lůžko), která je plnohodnotné lůžko pro hosta, ale v seznamu pevných postelí nemá co dělat. Tento plán rozšiřuje datový model, výpočet kapacity a popis pokoje o přistýlky.

Rozhodnutí z krátkého rozhovoru s uživatelem:
- **Formát**: nové volitelné pole `extraBeds?: number` na `Room` (mimo `beds`). Zachovává původní číselný zápis `beds: [1,2,2]` pro pevná lůžka.
- **Počet**: libovolný (0, 1, 2+).
- **Zobrazení**: v popisu pokoje explicitně vypsat `N× přistýlka` za pevnými lůžky.
- **Kapacita**: `sum(beds) + (extraBeds ?? 0)` — přistýlka = 1 osoba. Logika warningu (překročení kapacity → orange) se nemění, jen se kapacita zvýší.

## Soubory k úpravě

- `src/config/accommodations.ts` — datový model, helpery `roomCapacity` a `describeBeds`.

**Žádné další soubory upravovat není potřeba** — `AccommodationPanel.tsx` používá jen `roomCapacity(room)` a `describeBeds(room.beds)`, takže po úpravě těchto dvou helperů a signatury druhého (vzít celý `room`) se kalkulace i popis rozšíří automaticky.

## Změny

### 1. Typ `Room`

```ts
export type Room = {
  id: string;
  name: string;
  beds: Bed[];
  /** Počet přistýlek (rollaway). Volitelné, default 0. Počítá se do kapacity jako 1 osoba/kus. */
  extraBeds?: number;
};
```

### 2. `roomCapacity`

```ts
export function roomCapacity(room: Room): number {
  const bedsSum = room.beds.reduce((sum, bed) => sum + bed, 0);
  return bedsSum + (room.extraBeds ?? 0);
}
```

### 3. `describeBeds` → `describeRoom`

Současné `describeBeds(beds: Bed[])` neumí vidět přistýlky. Přejmenovat na `describeRoom(room: Room)` a vzít celý objekt:

```ts
export function describeRoom(room: Room): string {
  const ones = room.beds.filter((b) => b === 1).length;
  const twos = room.beds.filter((b) => b === 2).length;
  const extras = room.extraBeds ?? 0;
  const parts: string[] = [];
  if (ones) parts.push(`${ones}× jednolůžko`);
  if (twos) parts.push(`${twos}× dvoulůžko`);
  if (extras) parts.push(`${extras}× přistýlka`);
  return parts.join(', ');
}
```

A upravit volání v `AccommodationPanel.tsx`:

```tsx
// bylo:
<p>{describeBeds(room.beds)}, kapacita {capacity}</p>
// nové:
<p>{describeRoom(room)}, kapacita {capacity}</p>
```

Import update: `describeBeds` → `describeRoom` v `src/components/admin/AccommodationPanel.tsx:15`.

### 4. Validace

`validateAccommodations` nepotřebuje rozšíření — `extraBeds` je jen nezáporné číslo, což TS typ už garantuje (kdyby bylo záporné, obalit `beds.reduce` + přistýlka by vrátily špatnou kapacitu, ale to je uživatelský error). Pokud chceme striktní check, přidat:

```ts
if (room.extraBeds != null && (room.extraBeds < 0 || !Number.isInteger(room.extraBeds))) {
  throw new Error(`Neplatné extraBeds v "${acc.id}/${room.id}": ${room.extraBeds}`);
}
```

(Nepovinné — rozhodnu podle chuti během implementace. Pro jistotu to přidám, stojí to jeden `if`.)

### 5. Existující data v `accommodations`

Nechávám tak, jak jsou — žádný pokoj nemá `extraBeds`, takže `extraBeds ?? 0` = 0 a nic se nezmění. Uživatel si je doplní kde potřebuje (např. `{ id: 'r1', name: 'Pokoj 1', beds: [2], extraBeds: 1 }`).

## Verifikace

1. `pnpm tsc --noEmit` — TS musí projít. Jediný call site starého `describeBeds` je v `AccommodationPanel.tsx`; TS kompilace okamžitě upozorní, kdybych někde volání zapomněl.
2. `pnpm build` — bez chyb.
3. Dočasně do jednoho pokoje v configu přidat `extraBeds: 1`, spustit `pnpm dev`, otevřít `/admin`:
   - Popis pokoje obsahuje `…, 1× přistýlka`.
   - Kapacita v textu je o 1 větší.
   - Warning "Přeplněno" reaguje na zvýšenou kapacitu (pokoj s `beds: [2]` + `extraBeds: 1` = kapacita 3; přiřazení pozvánky se 4 lidmi zoranžoví).
4. Vrátit testovací `extraBeds` zpět nebo nechat, podle rozhodnutí uživatele.

## Co tento plán **ne**řeší

- Speciální vizuální odlišení přistýlek v UI (zvláštní ikonka, barva) — jen textový popis.
- Limity na počet přistýlek ("max 2 na pokoj") — ani runtime ani TS check; konfigurační hodnota, uživatel si hlídá sám.
- Migrace už uložených Firestore přiřazení — nic se v ukládání nemění, přiřazení stále drží jen `{accommodationId, roomId}`.
