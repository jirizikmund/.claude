# Projekt eFlight

## Commit messages

- Prefix s číslem tasku podle větve: `(#XXXX) popis`
- Nikdy nepřidávat zmínky o Claude Code, emoji ani Co-Authored-By

## Jazyk

- Komunikace probíhá česky

## Feedback

- [Prettier formatting](feedback_prettier.md) — vždy respektovat prettier konfiguraci při úpravách kódu
- [Bez automatické vizuální kontroly](feedback_no_auto_visual_check.md) — nespouštět inspector automaticky, uživatel kontroluje ručně
- [Používat existující UI komponenty](feedback_use_existing_components.md) — preferovat src/ui/components a src/components/common
- [Nevytvářet unit testy](feedback_no_tests.md) — v code review ani implementaci nenavrhovat testy
- [Nikdy neamendovat commity](feedback_no_amend.md) — amend jen na výslovný pokyn, jinak nový commit
- [Bez automatického push a PR](feedback_no_auto_pr.md) — žádný `git push` (ani na master) ani PR bez explicitního pokynu; „pokračuj" není autorizace

## Agenti (při startu VŽDY načíst z ~/.claude/agents/)

- **eflight-visual-inspector** — vizuální inspekce eFlight webu přes Playwright MCP. Ukládá screenshoty do `memory/screenshots/` s indexem. Používat pro kontrolu UI po změnách i pro procházení aktuálního stavu aplikace.
- **mobile-inspector** — inspekce mobilní aplikace přes Appium MCP (screenshot, elementy, navigace, interakce). Používat pro kontrolu mobilního UI.

## Struktura aplikace

- [Popis stránek a UI](app-pages.md)
- [Reservation form — architektura, crew, datový model](reservation-form-knowledge.md)
- [Checklist rezervace — znalosti](checklist-knowledge.md)

## Aktivní plány

- [Permit tab implementace (#1057)](1057-checklist-modifications.md) — hotovo
- [Checklist tester a dokumentace (#2598)](2598-checklist-tester.md) — hotovo
- [Airports/Country Notes záložky (#2264)](2264-airports-country-tabs.md)
- [Fix flightboard live update zaseknutí (#2559)](2559-flightboard-live-update-fix.md)
- [Fix chybějící local time odletu v popupu (#2558)](2558-scheduling-popup-local-time-fix.md)
- [Country Notes vizuální redesign (#2612)](2612-country-notes-visual-redesign.md)
- [Roster status v kalendáři (#2535)](2535-roster-calendar-display.md) — crew overlay, OFF, STANDBY, NO SCHEDULED CREW
- [Live flight updates v schedulingu (#2640)](2640-live-flight-updates.md) — FPL/CTOT/ETD/ETA v popupu, posun baru, duty calc