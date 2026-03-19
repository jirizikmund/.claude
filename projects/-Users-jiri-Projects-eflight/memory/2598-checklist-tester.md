---
name: "#2598 Checklist tester a dokumentace"
description: Interaktivní testovací stránka /ops/checklist-tester + kompletní dokumentace checklistové logiky v docs/guides/scheduling/checklist/
type: project
---

**Status:** Implementováno

## Checklist Tester (`/ops/checklist-tester`)

Standalone stránka pro testování checklistové logiky. Striktně readonly vůči API.

**Funkcionalita:**
- Načtení rezervace přes UUID nebo rezervační kód (GU9US)
- Overrides: čas odletu/příletu, simulated "now" (slider T-7d → T+1h), airport config (requestPeriodDays, EarlySlotWaitingList, configurableServices), typ letu, fuel type, pets
- Country config se testuje změnou ICAO letiště (žádná modifikace globální cache)
- Lokální potvrzování (confirmChecklist je čistě lokální funkce)
- Simulated time se promítá do confirmTime
- Override highlighting: červené pole + ↺ reset ikona, globální "Reset all"
- Docs modal: markdown + mermaid rendering přes CDN (marked, mermaid)

**Why:** `__dangerouslySetCountryCacheEntry_forTestingOnly` v Countries.ts — slouží POUZE pro country overrides v testeru, cleanup při unmount obnoví originální data

**Klíčové soubory:**
- `src/Admin/ChecklistTester/` — celý modul (6 souborů)
- `src/Admin/Admin.tsx` — route v FullAdminRouter
- `docs/guides/scheduling/checklist/tester.md` — dokumentace testeru

## Dokumentace (`docs/guides/scheduling/checklist/`)

7 souborů pokrývajících kompletní logiku checklistů:
- README, 01-visibility, 02-default-state, 03-flag-logic, 04-items-reference, 05-confirmation-lifecycle, 06-special-cases

Viz [checklist-knowledge.md](checklist-knowledge.md) pro přehled.
