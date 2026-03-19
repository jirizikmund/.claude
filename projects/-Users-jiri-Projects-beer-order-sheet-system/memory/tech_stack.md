---
name: Technický stack
description: Zvolené technologie pro BOSS — Next.js, PostgreSQL, Docker, Caddy, Puppeteer, shadcn/ui
type: project
---

**Frontend:** Next.js 14+ (App Router), TypeScript, React 18+, Tailwind CSS, shadcn/ui, next-intl, react-hook-form + zod, @dnd-kit, next-pwa, next-themes

**Backend:** Next.js Server Actions (CRUD) + API Routes (ARES, PDF, email, auth), Prisma ORM, NextAuth.js (credentials), Nodemailer (SMTP), Puppeteer (PDF)

**Databáze:** PostgreSQL (full-text search, Docker)

**Infrastruktura:** Docker + Docker Compose, Caddy (reverse proxy + Let's Encrypt SSL), Sentry (error monitoring), Pino (logging)

**Design:** shadcn/ui, dark/light/system theme, brand color #4E54F1, viz `docs/design-reference/`

**Hosting:** Český VPS (Wedos/Active24/Forpsi), min 2 vCPU, 4 GB RAM, 24/7 dostupnost

**CI/CD:** GitHub Actions (lint + typecheck + testy), Husky + lint-staged

**How to apply:** Package manager je pnpm. Architektura: Server Actions pro mutace, API Routes pro binary/proxy endpointy. CLAUDE.md v rootu má kompletní přehled konvencí.
