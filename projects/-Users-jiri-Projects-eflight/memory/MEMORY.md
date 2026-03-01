# Projekt eFlight

## Commit messages

- Prefix s číslem tasku podle větve: `(#XXXX) popis`
- Nikdy nepřidávat zmínky o Claude Code, emoji ani Co-Authored-By

## Jazyk

- Komunikace probíhá česky

## Agenti (při startu VŽDY načíst z ~/.claude/agents/)

- **eflight-visual-inspector** — vizuální inspekce eFlight webu přes Playwright MCP. Ukládá screenshoty do `memory/screenshots/` s indexem. Používat pro kontrolu UI po změnách i pro procházení aktuálního stavu aplikace.
- **mobile-inspector** — inspekce mobilní aplikace přes Appium MCP (screenshot, elementy, navigace, interakce). Používat pro kontrolu mobilního UI.

## Struktura aplikace

- [Popis stránek a UI](app-pages.md)

## Aktivní plány

- [Airports/Country Notes záložky (#2264)](2264-airports-country-tabs.md)
- [Fix flightboard live update zaseknutí (#2559)](2559-flightboard-live-update-fix.md)
- [Fix chybějící local time odletu v popupu (#2558)](2558-scheduling-popup-local-time-fix.md)