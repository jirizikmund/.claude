---
name: 2402-empty-legs-timeline-fix
description: Fix zvýraznění empty legs to remove na quote Aircraft Timeline (race s pozdním API) + znovudoplnění reservation code badge do leg popupu. Stav větve feat/2402 k 11.6.2026.
metadata: 
  node_type: memory
  type: project
  originSessionId: 73d1a7c2-5810-4043-826c-3ea1730d18a0
---

# #2402 follow-up (11.6.2026) — empty legs highlight + reservation code v popupu

## Bug: legy ke smazání se na quote ose nezvýrazňovaly

- `EmptyLegToRemove` = legy JINÝCH rezervací (viz [[duty-calculation-knowledge]]); na osu přijdou
  přes `getCalendar`, červeně (COLORS.danger) se barví jen při VYTVÁŘENÍ itemů podle
  `params.emptyLegs` (`useTimelineData.tsx` → `getDataItemsFromReservationForOneResource`).
- `emptyLegs` dorazí vždy až PO prvním loadu osy: aircraftProfile → mount QuotationCalculator
  (`useDidMountEffect`) → POST `/reservation/emptyLegsToRemove` → `onLoadEmptyLegs=setEmptyLegs`
  v ReservationForm → prop AircraftTimeline. Timeline mezitím načte data (debounce 500 ms).
- Starý mechanismus: příchod emptyLegs rozšíří okno (`useReservationTimeWindow`) → `setWindow` →
  `rangechange` → donačtou se OKRAJE okna už s červenou. Fungovalo JEN pro legy MIMO okno quote;
  pro legy uvnitř okna rozbité od vzniku (#2294, 9/2025) — itemy vznikly dřív a merge
  (`uniqBy` dle id, staré itemy vyhrávají) je nikdy nepřebarvil. Není to tedy nedávná regrese.
- **FIX** (commit `(#2402) Highlight empty legs to remove…`): v `useTimelineData.tsx` vytažen
  sdílený `getChildEventItemStyle` + `getReservationItemStyleParts`; nový `useEffect` na
  `[view, emptyLegs]` přepočítá `style` existujících child_event itemů (changed-check, propagace
  `onTimelineDataChange`). Hlavní kalendář předává `emptyLegs={undefined}` → effect no-op.
- Při diagnóze vyloučeno (pro budoucí debugging osy): vis-timeline 7.7→8.5 (`setWindow` s animací
  dál emituje `rangechange` každý frame), use-debounce 10.x (debounced/throttled fn má stabilní
  identitu, volá aktuální callback přes ref → staré closury v `initTimeline` nevadí), getCalendar
  refactor `fd9c0b773` (ekvivalentní), `filterCalendar` (fromOverview=false matchne vše),
  `deriveEffectiveTimes` (bez flight dat vrací scheduled časy).
- Mock: do 27.9.2025 (#1413) platil v dev fallback `result.data ?? MOCK_EMPTY_LEGS` — maskoval
  API chyby („dříve to fungovalo"). Dnes mrtvá konstanta v `CancelLegsModal.tsx`.
- Backend `/reservation/emptyLegsToRemove` (`amplify/backend/function/schedulingApi/src/app.ts`):
  vrací jen BUDOUCÍ legy (`evnt.dateFrom > new Date()`), okno ±2 dny kolem quote; `433e805a2`
  (8.5.2026) podmínky rozšířil. Latentní bug: když `toDelete.quotationId` odkazuje na
  nenalezitelnou quotation, `quotation.quotation` hodí TypeError → 500.
- **OTEVŘENÉ:** nepotvrzeno uživatelem, zda po fixu legy vidí. Rozlišení symptomu: cancel lines
  v Quotation Calculatoru = API data chodí. Pokud legy na ose chybí ÚPLNĚ (ne jen nečervené),
  jejich rezervace se nenačítá do ops dat osy — to je další, nevyřešená vrstva.

## Reservation code badge v leg hover popupu

- Uživatelova dřívější úprava („kód rezervace v pravém horním rohu popupu") v repu NIKDY nebyla —
  prohledány všechny větve (`git log --all -S`), stash, reflog i session transkripty. Znovu
  implementováno (commit `(#2402) Show reservation code badge…`): v headeru
  `LegPopupContent/index.tsx` vpravo `<Badge textVariant="black" variant="light">` v obalu
  `<View fullFlex align="center" justify="flex-end" marginLeft={20}>` — stejný styl jako badge
  kódu v `ModalHeader.tsx` (`badge bg-light text-black`).
- `reservationCode`: `reservationDataFromDb` (SchedulingTypes.ts) mapuje u quotation
  `input.quotationCode` → `reservation.reservationCode` (vždy `.toUpperCase()`) → popup funguje
  pro rezervace i quoty z jednoho pole.

## 12.6.2026 — skutečná hlavní příčina: prázdná osa z Sales → Overview → New (RFQ)

- Detail z Overview/New = **Avinode RFQ** konvertované přes `reservationDataFromRfqDb`
  (`Admin/Avinode/model/RfqType.ts`), NE DB quotace. Commit `c890217fd` (2.3.2026, #2401) přidal
  konverzi `diffCrewForEachEvent: true` + PIC/FO z rosteru do `childEvent.resources`.
- `getAllDataItemsFromReservation` (plní osu při `changeReservation`) při diffCrew brala resources
  JEN z legů → aircraft itemy nevznikly nikdy (letadlo jen na rezervaci); bez rosteru nevzniklo nic
  → osa prázdná, zatímco Simple Edit tabulka i kalkulátor legy mají (čtou `reservation.events`).
  Z kalendáře otevřené quotace mají diffCrew=false → fungovaly. Regrese od 2.3.2026.
- **FIX** (commit `0681bbdfc`, `(#2401) Show quote legs on aircraft timeline for diff-crew
  reservations`): resources = uniqBy(union `reservation.resources` + při diffCrew leg resources).
  Bonus: v hlavním kalendáři po editaci diff-crew rezervace bary nezmizí z řádku letadla.
- Review commitu `3ae543566` na žádost uživatele: nebyl zbytečný (řeší nezávislou vrstvu — pozdní
  zvýraznění OKOLNÍCH legů; tento bug je o QUOTE itemech) a chybu nezanesl (kalendář no-op,
  idempotentní styly, kompatibilní s duty errors).

## Duty kontrola na Overview/New (analýza 12.6.2026, bez změn kódu)

- `useReservationDutyErrors` funguje pro RFQ detail stejně jako z kalendáře (hook sedí
  v AircraftTimeline, na vstupní cestě nezávisí). Před fixem `0681bbdfc` ale nebylo KAM chyby
  kreslit (osa bez barů) — fix tedy zprovoznil i duty zobrazení.
- RFQ crew je výhradně z crewRosteru (per den+letadlo, relace cpt/fo); bez rosteru legy nemají
  piloty → hook nemá koho kontrolovat → žádné proužky/badge (očekávané, jako quotace bez crew).
- `resourceIsPilot` testuje ROLI (pic/fo, `pilotResourceRoles`), ne resource.type.
- Riziko (neopraveno, pre-existing): `isChildEventVisibleForResource` dělá `resources.some` bez
  `?? []` — diff-crew rezervace s `childEvent.resources === undefined` (DB konverze připouští)
  by shodila výpočet rozvrhu pilota → `.catch` v hooku duty tiše vyprázdní. Případný fix: `?? []`.

## Stav (12.6.2026)

- Větev `feat/2402` (3 commity: `3ae543566` empty legs highlight, `4ef2d881c` reservation code
  badge, `0681bbdfc` diff-crew/RFQ osa) **pushnuta uživatelem**; lokální master = origin/master.
- **PR #2757** „(#2402) Fix showing legs to be cancelled in quotation detail timeline" — otevřen
  uživatelem, popis (3 sekce dle commitů) doplněn 12.6. přes REST API.
- Obsah starého `e6638e81a` je v masteru jako `9301e6544` (PR #2738 MERGED, `git cherry` ověřeno).
