# Zasedací pořádek v adminu

## Context

Uživatel potřebuje v admin panelu organizovat zasedací pořádek pro svatbu. Aktuálně admin obsahuje statistiky, tabulku pozvánek a `AccommodationPanel` (přiřazování pokojů). Chybí volný 2D editor, kde lze umístit hosty kolem stolů.

Cíl: nová čtvercová sekce **Zasedací pořádek** pod ubytováním, kde lze drag&drop hosty (kteří potvrdili účast) po ploše a rozmísťovat libovolný počet stolů (obdélníky na pozadí, lze je posouvat, měnit velikost a mazat). Vše se persistuje do Firestore a synchronizuje mezi admini realtime.

## Rozhodnutí (výsledek diskuse)

- **Drag**: existující `@dnd-kit/core` (`useDraggable` bez `useDroppable`, free 2D positioning přes `event.delta`).
- **Resize stolu**: vlastní pointer events (dnd-kit resize neumí, samostatná knihovna by byla overkill).
- **Persistence**: save jen na pointer-up; `onSnapshot` listener pro live sync mezi admini; per-item `setDoc({merge:true})` aby pohyby různých položek nikdy nekolidovaly. Last-write-wins jen u stejné položky.
- **Souřadnice**: ukládat v procentech 0-1 vůči ploše, aby pozice fungovaly responsivně.
- **Filtr hostů**: `guest.attending === true` (včetně dětí — `isChild === true` taky sedí).
- **Menu fallback**: pomlčka „—" když host nemá vybrané menu.

## Datový model

Nová Firestore kolekce `seating`, jediný dokument `layout`:

```ts
type SeatingLayout = {
  guests: Record<string, { x: number; y: number }>;        // klíč: `${code}:${index}`
  tables: Record<string, { x: number; y: number; width: number; height: number }>;
};
// vše v procentech 0-1 vůči canvas
```

- `guestKey` = `${invitation.code}:${guestIndex}` — stabilní, přežije přejmenování.
- `tableId` = `crypto.randomUUID()` při „Přidat stůl".

## Soubory k vytvoření / úpravě

### Nové soubory

1. **`src/lib/seating.ts`** — typy `SeatingLayout`, `SeatingTable`, `SeatingGuestPosition`; helpers `subscribeSeatingLayout(cb)`, `saveGuestPosition(key, x, y)`, `saveTable(id, partial)`, `deleteTable(id)`. Pattern stejný jako `src/lib/accommodation-assignments.ts:1-60` ale s `onSnapshot` místo `getDoc`.

2. **`src/hooks/useSeatingLayout.ts`** — hook s `useEffect`+`onSnapshot`, vrací `{ layout, loading, error, saveGuest, saveTable, addTable, removeTable }`. Optimistický update: lokální `setLayout` ihned, Firestore async; rollback při chybě (vzor z `src/hooks/useAccommodationAssignments.ts`).

3. **`src/components/admin/SeatingPanel.tsx`** — hlavní komponenta sekce:
   - Wrapper `bg-white rounded-xl shadow-sm p-4 mb-6` (sjednocený se zbytkem AdminPage).
   - Header: `<h2>Zasedací pořádek</h2>` + tlačítko **Přidat stůl** vpravo.
   - Canvas: `<div ref={canvasRef} className="aspect-square relative border bg-gray-50 overflow-hidden rounded-lg">`.
   - Vykreslí stoly (z-0) a hosty (z-10) z `useSeatingLayout`.
   - DndContext (`PointerSensor` s 4px aktivační vzdáleností — stejný jako `AccommodationPanel`).
   - `onDragEnd`: rozliší `guest:` vs `table:` prefix v `event.active.id`, převede `event.delta.x/canvasWidth` na nové procento, clamp 0-1, volá hook.
   - Klik mimo stůl → deselect.

4. **`src/components/admin/SeatingGuestChip.tsx`** — `useDraggable({ id: \`guest:\${key}\` })`, ~140×56px, jméno + menu shortLabel (z `weddingConfig.menu.options`) nebo „—". Pozadí coral/sky-blue dle pohlaví? Ne, jednoduché bílé s borderem.

5. **`src/components/admin/SeatingTable.tsx`** — `useDraggable({ id: \`table:\${id}\` })`. Klik (bez tahu, detekce přes onPointerDown→onPointerUp bez pohybu) vybere stůl. Vybraný stůl má:
   - X tlačítko (top-right) → `removeTable(id)` po confirm.
   - Resize handle (bottom-right, 12×12px). Pointer events: `onPointerDown` → `setPointerCapture`, `pointermove` aktualizuje width/height v procentech, `pointerup` → `saveTable(id, {width, height})`. `e.stopPropagation()` aby se nezačal drag.
   - Outline `ring-2 ring-coral`.
   Nevybraný = pouze obdélník `bg-amber-100/60 border border-amber-300 rounded`.

### Úpravy existujících souborů

6. **`src/pages/AdminPage.tsx`** — pod `<AccommodationPanel />` přidat `<SeatingPanel invitations={invitations} />`. Načtení invitations už tam je (`listInvitations`).

7. **`firestore.rules`** — pod `match /accommodations/{docId}`:
   ```
   match /seating/{docId} {
     allow read, write: if isAdmin();
   }
   ```

## Klíčové funkce a patterns k reuse

- **`listInvitations()`** — `src/lib/firestore.ts:69` — už použito v AdminPage.
- **Filtr potvrzených** — `guest.attending === true` (vzor z `src/lib/rsvp-stats.ts:56`).
- **Menu shortLabel** — `weddingConfig.menu.options[i].shortLabel` (`src/config/wedding.ts:79-105`).
- **dnd-kit setup** — `src/components/admin/AccommodationPanel.tsx` ukazuje DndContext + PointerSensor; můj use-case je jednodušší (žádné droppable).
- **Firestore optimistický update** — `src/hooks/useAccommodationAssignments.ts` (vzor pro setDoc s merge + rollback).
- **Tailwind v4 colors** — `src/index.css` `@theme` má `--color-coral`, `--color-sky-blue`, `--color-cream` atd., používat je.

## Algoritmus 2D drag (dnd-kit bez droppable)

```
useDraggable({ id: `guest:${key}` }) vrátí transform.{x,y} v px během dragu.
Vykreslit: style.left = `${pos.x * 100}%`, top = `${pos.y * 100}%`,
           transform: transform ? `translate(${transform.x}px, ${transform.y}px)` : undefined

onDragEnd(event):
  const rect = canvasRef.current.getBoundingClientRect()
  const newX = clamp(oldX + event.delta.x / rect.width, 0, 1 - chipW/rect.width)
  const newY = clamp(oldY + event.delta.y / rect.height, 0, 1 - chipH/rect.height)
  saveGuest(key, newX, newY)
```

Stůl funguje stejně, jen ID prefix `table:`.

## Resize handle (vlastní pointer events)

```
onPointerDown(e):
  e.stopPropagation()
  e.currentTarget.setPointerCapture(e.pointerId)
  startW = table.width; startH = table.height
  startX = e.clientX; startY = e.clientY
onPointerMove(e):
  if (!captured) return
  const rect = canvasRef.current.getBoundingClientRect()
  const newW = clamp(startW + (e.clientX - startX) / rect.width, 0.05, 1)
  const newH = clamp(startH + (e.clientY - startY) / rect.height, 0.05, 1)
  setLocalSize({w: newW, h: newH})  // optimistic
onPointerUp(e):
  saveTable(id, { width: localSize.w, height: localSize.h })
  captured = false
```

## Verifikace

1. `pnpm tsc --noEmit` — typy projdou.
2. `pnpm build` — produkční build projde bez warningů.
3. `pnpm dev`, otevřít `/admin`, přihlásit, scrollovat pod ubytování:
   - Sekce „Zasedací pořádek" je viditelná, čtvercová, max-w odpovídá zbytku.
   - Vidím chip pro každého hosta s `attending === true` (včetně dětí), zobrazí jméno + menu (nebo „—").
   - Drag chipu = pohne se a zůstane na nové pozici po reloadu.
   - „Přidat stůl" → na ploše se objeví obdélník na pozadí (pod chipy).
   - Klik na stůl → ring + X + resize handle. Drag stolu = pohyb. Drag handle = změna velikosti. X = smazání po confirm.
   - Reload → vše tam, kde jsem nechal.
4. Otevřít admin v druhém okně/anonymu, přihlásit druhým adminem (nebo simulovat přes druhý tab) → posuny se mezi okny šíří díky `onSnapshot`.
5. Firestore rules: `firebase deploy --only firestore:rules` (nezapomenout — uživatel deployuje sám).

## Známé limity

- **Stejný host/stůl tažený dvěma admini současně** = last-write-wins (pravděpodobnost mizivá pro 1-2 admin).
- **Resize jen z pravého dolního rohu** — pro 4-rohovou variantu by byla další 3 pointer event listenery; přidání kdykoliv později.
- **Mobile**: drag funguje (PointerSensor), ale aspect-square čtverec na mobilu zabere celou výšku. Admin se primárně používá na desktopu, není kritické.
