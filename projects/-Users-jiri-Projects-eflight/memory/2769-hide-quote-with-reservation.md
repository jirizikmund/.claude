---
name: 2769-hide-quote-with-reservation
description: "#2769 — v sales kalendáři skrýt quotu, ze které už vznikla rezervace (na ose jen rezervace). Centrální filtr v postprocessAndPropagateChange."
metadata: 
  node_type: memory
  type: project
  originSessionId: 73d1a7c2-5810-4043-826c-3ea1730d18a0
---

# #2769 — Skrýt quotu s vytvořenou rezervací ze sales timeline

**Stav (15.6.2026): HOTOVO.** Commit `(#2769) Hide quote with created reservation from sales
timeline` na větvi `feat/2769`, **PR #2770** (otevřen, popis doplněn). Lokální master vrácen na
origin/master.

## Problém

V **sales** kalendáři se po potvrzení quotace zobrazovala na časové ose ZÁROVEŇ původní quota
i rezervace z ní vytvořená. Mělo zůstat jen rezervace.

## Příčina

Filtr `cleanCalendarLines` (v `useTimelineData.tsx`) quoty s vytvořenou rezervací odstraňoval,
ale jen pro dávky načítané z `getCalendar`. Quoty se na osu vracely i živými cestami, které ho
obcházejí: `changeReservation` ze subscription / uložení formuláře (v sales view klik na rezervaci
otevírá ve formuláři její QUOTU → každé uložení vrátí itemy quoty), a `uniqBy` merge nechával staré
itemy quoty z dřívějších dávek.

## Řešení

Nová `removeQuotesWithCreatedReservation(data, view)` aplikovaná centrálně v
`postprocessAndPropagateChange` — jediném hrdle, kterým prochází KAŽDÁ mutace dat osy (loady,
changeReservation, addCreatedReservation, flight statusy, roster pozadí). V sales view posbírá
`quotationId` ze všech rezervací vytvořených z quot (`isReservationCreatedFromQuote`) a odstraní
itemy odpovídajících quot, pak přepočítá `addBetweens` (mezery). No-op v ops view a když není co
odstranit (vrací identická data → žádné zbytečné překreslení). Helper `getItemReservation` čte
reservation z child_event i reservation itemu.

## Známá limitace (mimo scope, NEvyřešeno)

Hned po potvrzení quotace se nová rezervace na sales ose sama neobjeví — sales kalendář subscribuje
jen quotace (`subscribeToQuotations`), rezervace dorazí až s dalším načtením (F5 / scroll do
nenačteného období); v tu chvíli quota zmizí. Okamžité zobrazení by chtělo subscribovat i rezervace
v sales view, nebo ruční `addCreatedReservation` po `createReservationFromQuotationId`.

Souvisí: [[scheduling-calendar-knowledge]], [[2402-empty-legs-timeline-fix]] (stejný soubor/hrdlo).
