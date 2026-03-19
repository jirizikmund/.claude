# Diggerman - Project Memory

## Startup checklist
- Pri kazdem spusteni si precti `docs/PLAN.md` pro kontext o projektu

## Project overview
- 2D mobilni hra - vertikalni scrolling digger
- Hrac s lopatou prokopava cestu dolu, obrazovka se automaticky posouvá
- Tech stack: Phaser 3 + Vite + Capacitor (TypeScript)
- Portrait orientace, cartoon/vector styl
- Package manager: pnpm

## Key files
- `docs/PLAN.md` - kompletni implementacni plan a architektura
- `src/main.ts` - entry point
- `src/config.ts` - herni konstanty
- `src/scenes/` - Boot, Menu, Game, GameOver sceny
- `src/objects/` - Player, Grid, Block, PowerUp
- `src/generators/LevelGenerator.ts` - proceduralni generovani
- `src/managers/` - Score, Scroll, Input managery

## Workflow
- Commitovat vždy po logických celcích (ne hromadně na konci)
- S každým commitem bumpnout patch verzi v package.json (zobrazuje se v HUD hry)

## Commands
- `pnpm dev` - dev server
- `pnpm build` - production build
- `pnpm preview` - nahled buildu
