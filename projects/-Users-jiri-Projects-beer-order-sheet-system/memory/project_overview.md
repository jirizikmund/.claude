---
name: Beer Order Sheet System - přehled projektu
description: Webová aplikace pro zaměstnance Plzeňského Prazdroje na vytváření objednávek přepravy piva. PDF výstup se posílá emailem dopravci.
type: project
---

Systém pro správu objednávek přepravy piva pro Plzeňský Prazdroj (BOSS).

**Co to dělá:** Zaměstnanci Prazdroje (desítky uživatelů) vytvářejí objednávky přepravy piva. Výstupem je PDF "Smlouva o přepravě věcí" — volitelně odeslaná emailem dopravci.

**Klíčové vlastnosti:**
- Mobile-first PWA, dark/light/system theme
- Vícejazyčnost (CZ/EN/DE, rozšiřitelné), jazyk PDF/emailu nezávislý na UI
- Formulář vizuálně identický s PDF
- Objednávky: draft → confirmed (nevratné), draft lze smazat, duplikace objednávek
- Číselná řada: YYYYMMDD/NNN (generuje se při potvrzení)
- Email odesílání volitelné, kdykoliv po potvrzení, opakovaně s dialogem
- PDF archivace v DB per jazyk, draft PDF s watermarkem
- Konfigurovatelné: PDF texty, logo, email šablona, PDF filename — vše vícejazyčně v admin UI
- Role: admin (správa uživatelů, konfigurace) a běžný uživatel
- Dopravce: 3 režimy (ručně/ARES/kontakt), ARES cache
- Reset hesla, aktivace účtu přes email
- Výchozí objednatel v admin konfiguraci

**How to apply:** Veškerá analýza v `docs/analysis.md`, plán v `docs/implementation-plan.md`, designové reference v `docs/design-reference/`. Vždy přečíst CLAUDE.md v rootu projektu.
