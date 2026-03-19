# rnkit Memory Index

## Projekt

- **Typ**: React Native knihovna (sdílená mezi projekty)
- **Package manager**: yarn (Yarn 4)
- **Build**: `yarn build` (interaktivní — nelze spustit neinteraktivně), type-check: `yarn tsc`
- **Cílový projekt**: `/Users/jiri/Projects/mtms-mobile-app`

## Architektura

Viz [architecture.md](./architecture.md) — config systém, build-time generování, skripty, exporty

## Git commit pravidla

- **NIKDY** nepřidávat `Co-Authored-By: Claude` ani žádné zmínky o Claude do commit messages
- Používat conventional commits formát (feat:, fix:, docs:, chore: atd.)

## Sentry integrace (task #428)

Viz [0428-sentry-implementation.md](./0428-sentry-implementation.md) — implementováno, stav: DONE
