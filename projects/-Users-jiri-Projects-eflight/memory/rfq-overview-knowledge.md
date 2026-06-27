---
name: rfq-overview-knowledge
description: "Sales Overview (New/Quotes/Reservations/Archived) — datové zdroje, konverze Avinode RFQ → Reservation (reservationDataFromRfqDb), crew z rosteru, odlišnosti od DB quotací"
metadata: 
  node_type: memory
  type: project
  originSessionId: 73d1a7c2-5810-4043-826c-3ea1730d18a0
---

# Sales Overview a Avinode RFQ → Reservation

## Datové zdroje tabů (`useOverview` → `getSalesOverviewData`, `Avinode/DataSources/rfq.ts`)

- **New** = POUZE `getRfqsData({state:'new'})` — `AvinodeQuoteRequest` záznamy (GraphQL
  `listAvinodeQuoteRequestByStateAndDateTo`), konvertované na Reservation. ŽÁDNÉ DB quotace.
- **Quotes** = `getReservations({isQuotation:true, fromOverview:true})` + RFQ `avinodeconfirmed`.
- **Reservations** = quotace se state 'reservation' + contractStatuses signed/sent.
- **Archived** = RFQ archived + quotace archived.
- Ops Overview = `getReservations({isQuotation:false, fromOverview:true})`.
- Detail se otevírá přes sdílený `EditReservationModal` s `resource={undefined}` (overview nemá
  kontext linky) a `isQuotation = isSalesView`.

## Konverze `reservationDataFromRfqDb` (`Admin/Avinode/model/RfqType.ts`)

Z `input.extractedData` (JSON `ExtractedDataType`) staví Reservation:

- `id` = RFQ id; `reservationCode` = `parsedQuote.tripId`; `isExternal: true`; `isUnconfirmed: true`;
  `type: charter_flight`; `flightType: multileg`; `quotationCalculation` = prázdná struktura.
- **`diffCrewForEachEvent: true`** (od `c890217fd`, 2.3.2026, #2401 „fill pilots to avinode
  requests") — POZOR na všechny code paths větvící podle diffCrew.
- ChildEventy: z `parsedQuote.legs`; `id = uuid.v4()` (nové při každém načtení!), `dateFrom` =
  departureDate, `dateTo` = departure + vypočtená doba letu (perf profil letadla, fallback 60 min),
  `resources: []` na začátku.
- Aircraft: match `resource.title === aircraftRegistration` proti flotile; když matchne, přidá se
  JEN do `reservation.resources` (role aircraft). Bez matche zůstávají resources prázdné →
  AircraftTimeline ukáže „No aircraft ID".
- **Crew: výhradně z crewRosteru** — per den legu hledá `WeeklyRoster` relace `cpt`/`fo` pro dané
  letadlo a pushuje `{role: pic|fo, resource}` (resource z `loadContactResources`) do
  `childEvent.resources`. Bez rosteru legy crew NEMAJÍ (nelze ovlivnit formulářem).
- `connectChain` dopočítává empty legy řetězením s okolními lety (±7 dní, `getReservations fromDb`).
- Jednodušší varianta `reservationDataFromRfqDbSimple` (subscriptions): bez aircraftu, bez crew,
  dateTo = departure + 60 min.

## Důsledky / pasti

- RFQ rezervace je efemérní objekt (uuid id legů, žádná DB quotationData) — edity se ukládají až
  uložením quotace.
- diffCrew=true + crew jen na legách → komponenty beroucí resources jen z jedné úrovně se rozbijí;
  na ose to řešil fix `0681bbdfc` (union reservation.resources + leg resources
  v `getAllDataItemsFromReservation`) — viz [[2402-empty-legs-timeline-fix]].
- Duty norma na RFQ detailu: funguje přes [[2402-duty-reservation-timeline]] hook, ale jen
  s narostovanou posádkou (viz výše).
