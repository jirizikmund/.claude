---
name: eflight-pou-v-npm
description: "Projekt eFlight používá npm (package-lock.json), ne pnpm — navzdory globální preferenci pnpm."
metadata: 
  node_type: memory
  type: project
  originSessionId: 507176ec-a2ba-40c8-85c9-91c10468caf6
---

Projekt eFlight používá **npm** — má `package-lock.json`, žádný `pnpm-lock.yaml`.

**Why:** Globální CLAUDE.md preferuje pnpm, ale to platí jen pro NOVÉ projekty. eFlight je existující npm projekt.

**How to apply:**
- Pro instalaci závislostí používat `npm install`, ne `pnpm install` (ten by vytvořil cizí `pnpm-lock.yaml`).
- `npx <tool>` nebo `npm run <script>` pro spouštění.
- `pnpm <tool>` jako runner sice funguje (spustí binárku z node_modules), ale pro konzistenci používat `npm`/`npx`.
