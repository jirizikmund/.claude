---
name: Country Notes vizuální redesign (#2612)
description: Plán vizuálního vylepšení formuláře CountryDetail na stránce /ops/airports/country-notes — Card seskupení, Bootstrap ikony, grid layout
type: project
---

# Vizuální vylepšení Country Notes stránky (#2612)

## Context

Stránka `/ops/airports/country-notes` zobrazuje formulář `CountryDetail` pro editaci country informací (Czech Republic, LK prefix). Aktuální stav:

**Vizuální problémy (z inspekce screenshotů):**
- Plochý lineární seznam polí — žádné vizuální seskupení, vypadá jako dlouhý "Google Form"
- Emoji tlačítka (cross, plus) v ICAOS listu — nestyled, renderují se různě na OS
- ICAOS inputy nemají `form-control` class — jsou výrazně užší a jiné než ostatní pole
- ISO2 a ISO3 zabírají každé celou šířku zbytečně (obsahují 2-3 znaky)
- Badges (EU, Permit EU, Permit 3rd Country, Genedec) jsou na Airports tabu, ale na Country Notes tabu chybí
- Checkboxy jsou rozsypané pod sebou bez logického seskupení
- Dva Save mechanismy (RichTextEditor auto-save + spodní button) bez vysvětlení
- Permit pole (Days, Hours) zabírají celou šířku pro čísla

**Design systém projektu:**
- Bootstrap 5.3.8 + Tailwind CSS hybrid
- Primary: `#147EFB` (custom blue)
- System font stack
- Card komponenta: `plain` (border + white bg), `gray`, `danger` varianty
- ListSection + SectionContainer pattern pro sekční formuláře
- Form controls: Bootstrap `.form-control`, pill-shaped buttons (border-radius 20px)
- Bootstrap icons: `<i className="bi bi-{name}" />`

**Why:** Stránka vypadá nedodělaně a neprofesionálně ve srovnání s ostatními admin sekcemi (Documents, PriceProfile), které používají Card/SectionContainer pattern.

**How to apply:** Při implementaci použít existující projektové komponenty (Card, bootstrap-icons) a zachovat Bootstrap + Tailwind styling.

## Design rozhodnutí

**Přístup:** Použít `Card` komponentu (`src/ui/components/card/Card.tsx`, variant `plain`, `titleSize="sm"`) pro vizuální seskupení do 3 sekcí. Card je ideální protože formulář je kompaktní a potřebuje jasné vizuální hranice, ne sticky headers.

**Estetický směr:** Čistý, utilitární admin styl — konzistentní s ostatními admin stránkami. Vylepšení spočívá v organizaci, ne v přidávání dekorací.

## Soubory k úpravě

1. **`/src/Admin/Countries/screen/CountryDetail.tsx`** — hlavní formulář
2. **`/src/Admin/Countries/screen/StringListForm.tsx`** — ICAO prefix list editor

## Plán implementace

### 1. StringListForm.tsx — Bootstrap ikony a form-control styling

**Změny:**
- Nahradit emoji cross za `<button className="btn btn-outline-secondary btn-sm"><i className="bi bi-x-lg" /></button>`
- Nahradit emoji plus za `<button className="btn btn-outline-primary btn-sm"><i className="bi bi-plus-lg" /> Add</button>`
- Přidat `form-control form-control-sm` class na input elementy
- Přidat `align-items-center` na flex kontejnery

### 2. CountryDetail.tsx — Card seskupení + layout vylepšení

**Import přidat:** `Card` z `../../../ui/components/card/Card`

**Nová struktura:**

```
<div className="flex flex-col gap-4">

  Card title="General" type="plain" titleSize="sm"
  +-- ICAOS (StringListForm)
  +-- Name *
  +-- [ISO2] [ISO3] v grid grid-cols-2 gap-3

  Card title="Country Note" type="plain" titleSize="sm"
  +-- RichTextEditor (auto-save beze změny)

  Card title="Permit & Compliance" type="plain" titleSize="sm"
  +-- [Permit request period] [Permit tolerance] v grid grid-cols-2 gap-3
  +-- Permit required for flights (select)
  +-- <hr>
  +-- Checkboxy v d-flex flex-wrap gap-4:
      Gendec required | Is EU | Permit EU (podmíněný) | Permit 3rd Country (podmíněný)

  Save button
</div>
```

### 3. Drobné opravy

- Opravit `htmlFor="iso3"` na poli Note -> `htmlFor="note"`
- Opravit `htmlFor="genedecRequired"` na select Permit required -> `htmlFor="permitRequiredForFlights"`

## Existující komponenty k využití

| Komponenta | Import path |
|---|---|
| Card | `../../../ui/components/card/Card` |
| Spinner | `../../../ui` |
| RichTextEditor | `../../../components/RichTextEditor/RichTextEditor` |
| Bootstrap icons | `<i className="bi bi-x-lg" />`, `<i className="bi bi-plus-lg" />` |

## Verifikace

1. `pnpm tsc --noEmit` pro TS kontrolu
2. Vizuální kontrola eflight-visual-inspector agentem
3. Funkční test: ICAO add/remove, note save, permit save, Is EU toggle
