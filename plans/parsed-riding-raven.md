# Stav implementace BOSS — Beer Order Sheet System

## Hotové fáze

| Fáze | Stav |
|------|------|
| 1. Kostra projektu (Next.js, Docker, Prisma, shadcn/ui, DM Sans, dark mode paleta) | ✅ |
| 2. CI/CD (GitHub Actions, Husky + lint-staged) | ✅ |
| 3. Autentizace (login, logout, aktivace účtu, reset hesla, middleware) | ✅ |
| 4. i18n (next-intl, CZ/EN/DE, locale + theme switcher) | ✅ |
| 5. Administrace — 5.1-5.3 (users CRUD, orderers CRUD, default orderer) | ✅ |
| 5.4-5.5 Konfigurace PDF/email textů v admin | ❌ odloženo |
| 6. Kontakty dopravců (CRUD, search, modal) | ✅ |
| 7A. Formulář objednávky (hlavička, dopravce manuálně, položky, draft save) | ✅ |
| 7B. Dopravce ARES + kontakt (ARES proxy s cache, výběr z kontaktů, uložení kontaktu) | ✅ |
| 7C. Drag & drop + chronologická validace (reorder mode s compact view) | ✅ |
| 8. Seznam objednávek (stránkování, filtry, fulltext) | ❌ další |
| 9. PDF generování + potvrzení objednávky | ❌ |
| 10. Odesílání emailů s objednávkou | ❌ |
| 11. PWA | ❌ |
| 12. Monitoring (Sentry, Pino) | ❌ |
| 13. Testování a nasazení | ❌ |

## Další krok
Fáze 8: Seznam objednávek — server-side stránkování, filtry (stav, objednatel, dopravce, datum, fulltext), tabulka/kartičky s responsivním designem.

## Klíčové implementační detaily
- Order slug: 5-char alphanumeric (URL-friendly, case-insensitive, no ambiguous chars)
- Dev DB workflow: `pnpm db:push` (ne migrace), migrace až pro produkci
- Country: ISO 3166-1 alpha-2, statický config s enabled list (ne DB tabulka)
- Prisma 6 (ne 7 — Prisma 7 měla breaking changes)
- SMTP fallback: bez konfigurace se emaily logují do konzole
