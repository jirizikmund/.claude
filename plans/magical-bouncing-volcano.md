# Plán: Role `superadmin` + rozšíření audit logu

## Context

Dnes má BOSS 2-role model (`admin` | `user`). Požadavky:

1. **Nová role `superadmin`** nad existujícími rolemi
   - Jediný má **přístup k audit logu** (`/admin/audit-log`)
   - Jediný může **přidělovat roli `superadmin`** jinému uživateli
   - Admin může vytvářet/upravovat `user` a `admin` (ale ne `superadmin`) — dle upřesnění
2. **Rozšířit audit log** o všechny admin akce, které dnes nejsou pokryté (uživatel tvrdí, že v audit logu nevidí akce z administrace, např. validation config).

Existující `admin@boss.local` zůstane `admin`. Nový `superadmin` se vytvoří seedem (a/nebo ručně v DB jako u Jana Bebra).

---

## Architektonická rozhodnutí (potvrzená s uživatelem)

| Oblast | Rozhodnutí |
|---|---|
| Superadmin = **singleton**, natvrdo v DB | Role `superadmin` **nelze přidělit přes UI**. Existuje vždy jen ten, který byl vytvořen seedem nebo manuálně v DB. Přidělování role přes server action odmítnuto Zod schématem. |
| Existující `admin` | Zůstává `admin` (admin@boss.local). Nic se nemění. |
| Bootstrap superadmina | Seed (`prisma/seed.ts`) — idempotentní `upsert` pro `superadmin@boss.local`, heslo z env `SUPERADMIN_SEED_PASSWORD` (prod fail bez env, dev fallback default s warningem). |
| Viditelnost superadminů v users seznamu | Admin seznam nevidí žádné superadminy. Superadmin vidí všechny (včetně sebe). Filtr přímo v DB query v `getUsers()`. |
| Auth self-service audit | Logovat (`activateAccount`, `requestPasswordReset`, `resetPassword`) |
| Validace polí audit | `saveFieldConfig` — pokrývá "Validace hodnot" (global + per-customer + per-carrier — jeden action entry point) |
| PDF audit | Logovat jen při prvním vytvoření `OrderPdfArchive` per jazyk, ne při každém stažení |
| Audit log čas | Zobrazit s vteřinami (formát `DD.MM.YYYY HH:MM:SS`) |

---

## Změny v kódu

### 1. DB schema — nový enum value

`prisma/schema.prisma:13-16`:
```prisma
enum UserRole {
  superadmin
  admin
  user
}
```

Deploy: `prisma db push --accept-data-loss` (Postgres enum rozšíření je bezpečné, žádná data nezmizí).

### 2. Auth guard — nová helper funkce

`src/lib/auth-guard.ts`:
- Rozšířit `AuthGuardErrorCode` o `'NOT_SUPERADMIN'`
- `requireAdmin()` (L41-45) — povolit `admin` **i** `superadmin` (superadmin má supermnožinu admin práv)
- Přidat `requireSuperAdmin()` — povolí jen `superadmin`

### 3. Audit log viewer — guard na superadmin

- `src/actions/audit.ts:30` — změnit `await requireAdmin()` → `await requireSuperAdmin()` v `getAuditLogs()`
- `src/app/admin/audit-log/page.tsx` — přidat `await requireSuperAdmin()` nebo lépe vytvořit `src/app/admin/audit-log/layout.tsx` s guardem
- `src/app/admin/admin-nav.tsx` — link "Audit log" zobrazit jen pro `session.user.role === 'superadmin'`

### 4. User management — restrikce

**Zod schema (žádná změna v enumu):**
- `src/schemas/user.ts:11,20` — **zůstává** `z.enum(['admin', 'user'])`. Superadmin nejde přidělit ani přes API — Zod payload s `role: 'superadmin'` je odmítnut parserem dřív, než se dostane do DB.

**Server actions (ochrana existujícího superadmina proti admin session):**
- `src/actions/users.ts:updateUser` (L84) — před update načíst target a zkontrolovat:
  ```ts
  const target = await db.user.findUnique({ where: { id }, select: { role: true } });
  if (target?.role === 'superadmin' && session.user.role !== 'superadmin') {
    return { error: 'Superadmina lze upravit jen jako superadmin' };
  }
  ```
- `src/actions/users.ts:deactivateUser` (L110), `deleteUser` (L150) — stejná ochrana: admin nemůže zasáhnout usera s `role === 'superadmin'`. Bez tohoto by admin mohl superadmina deaktivovat pomocí znalosti jeho ID.
- `src/actions/users.ts:createUser`, `resendActivationEmail` — bez změny (nelze vytvořit usera s `role: 'superadmin'`, protože Zod to odmítne)

**Seznam userů — skrýt superadminy pro admin session:**
- `src/actions/users.ts:21-37` — `getUsers()` — filtrovat v DB:
  ```ts
  const session = await requireAdmin();
  return db.user.findMany({
    where: session.user.role === 'superadmin' ? undefined : { role: { not: 'superadmin' } },
    orderBy: { createdAt: 'desc' },
    select: { ... },
  });
  ```
  Admin v `/admin/users` neuvidí žádného superadmina; superadmin vidí všechny (včetně sebe).

**UI (admin users page) — zjednodušení díky singleton:**
- `src/app/admin/users/create-user-button.tsx:77-84` — **žádná** option `superadmin` v selectu (role se nedá přidělit přes UI)
- `src/app/admin/users/edit-user-modal.tsx:63-70` — totéž; select má jen `user` a `admin`. Protože `getUsers()` filtruje superadminy pro admin session, modal edit superadmina se nedostane k admin UI vůbec. Superadmin pak edituje sebe (nebo jiný superadmina, pokud by byl) — role selector mu to dovolí, ale Zod schema odmítne jakoukoliv jinou než `admin/user` → superadmin nemůže downgradovat sebe přes UI. Tím je ochrana proti self-demote automatická.
- `src/app/admin/users/user-list.tsx` — bez změny (admin nevidí superadmin rows, superadmin vidí všechno)

**Ochrana proti self-lockout** — není potřeba řešit explicitně: superadmin nemůže sobě odebrat roli (Zod), nemůže sebe smazat (stávající logika `deleteUser` vyžaduje `!passwordHash`, a aktivní superadmin má heslo).

### 5. Rozšíření audit log — typy

`src/lib/audit.ts`:
- `AuditEntityType` — přidat `'field-validation'`
- `AuditAction` — přidat `'activate'`, `'resend-activation'`, `'password-reset-request'`, `'password-reset'`, `'generate-pdf'`

### 6. Audit log — chybějící coverage

| File | Function | Entity | Action | Co logovat |
|---|---|---|---|---|
| `src/actions/field-config.ts:134` | `saveFieldConfig` | `field-validation` | `update` | before = snapshot původních configs pro scope+override, after = nové configs. `entityId` = `${scope}:${customerId ?? 'global'}:${carrierId ?? '-'}`. Před `deleteMany` načíst starý stav. |
| `src/actions/users.ts:175` | `resendActivationEmail` | `user` | `resend-activation` | userId (admin), entityId = target user id |
| `src/actions/auth.ts:23` | `activateAccount` | `user` | `activate` | userId = target user (self-service), po úspěšném `db.user.update` |
| `src/actions/auth.ts:53` | `requestPasswordReset` | `user` | `password-reset-request` | pouze pokud user existuje (po `db.user.update` s tokenem). Nelogovat failed attempts na neexistující email (email enumeration protection). |
| `src/actions/auth.ts:81` | `resetPassword` | `user` | `password-reset` | po úspěšném `db.user.update`, userId = target user |
| `src/app/api/orders/[slug]/pdf/route.ts:53-60` | GET handler | `order` | `generate-pdf` | jen v `else` větvi (prvogenerace per jazyk); `after: { language }` |

**Důležité:** `auditLog()` v `auth.ts` akcích — tyto jsou self-service (není `session` z auth-guard), `userId` musí být ID dotčeného uživatele, ne invoker. Rate-limit je řešený v `enforceAuthRateLimit` — auditLog logovat teprve po ověření že akce proběhla úspěšně (DB update).

**Důležité v PDF route:** `src/app/api/orders/[slug]/pdf/route.ts:35` — role check `!== 'admin'` musí povolit i `superadmin`. Změna: `!['admin', 'superadmin'].includes(session.user.role)`.

### 7. Seed — nový superadmin user (idempotentní)

`prisma/seed.ts`:
- Po admin seedu (L22-36) přidat druhý `prisma.user.upsert` pro `superadmin@boss.local` s rolí `superadmin`
- Heslo z env `SUPERADMIN_SEED_PASSWORD`:
  - `NODE_ENV=production` a env chybí → throw (stejně jako u `ADMIN_SEED_PASSWORD`)
  - dev bez env → fallback `superadmin123` + warning
- `upsert` s `update: {}` = pokud už existuje, **nepřepisuje heslo** (idempotentní, bezpečné opakovat)
- Pro test VPS: spustit seed přes compose profile (`--profile seed run --rm seed`), ale env `SUPERADMIN_SEED_PASSWORD` dát do `.env` — dokumentovat v `reference_deploy_commands.md`

### 8. i18n

`messages/cs.json`, `en.json`, `de.json`:
- Přidat `admin.users.roleSuperAdmin` (cs: "Superadmin", en: "Superadmin", de: "Superadmin")
- Pokud existují popisky pro role v badge/filteru — doplnit
- Rozšířit i18n texty pro audit log actions (activate, resend-activation, password-reset-request, password-reset, generate-pdf)

### 8a. Audit log — zobrazení času s vteřinami

`src/lib/format.ts`:
- Buď přidat `second: '2-digit'` do `defaultDateTimeOptions` (globálně — dopad na všechna volání `formatDateTime`), **nebo** — preferované — přidat novou funkci `formatDateTimeWithSeconds(value, locale)` se stejným formátem + `second: '2-digit'`.

`src/app/admin/audit-log/audit-log-table.tsx`:
- Volání na L126 (`primitiveToString`) a L175 (createdAt sloupec) použít `formatDateTimeWithSeconds` místo `formatDateTime`.
- Výsledek např.: `20.04.2026 15:37:42` (cs locale, h23).

### 9. Aktualizace `CLAUDE.md`

Sekce "Role":
```
- **superadmin**: vše co admin + audit log + přidělení role superadmin
- **admin**: správa uživatelů (user/admin), validace, objednatelé, dopravci, zákazníci
- **user**: objednávky (CRUD, potvrzení, odesílání)
```

---

## Data migrace

- Lokálně: `pnpm db:push` (rozšíření enum) + `pnpm db:seed` s `SUPERADMIN_SEED_PASSWORD=...` v env
- Test VPS: standardní deploy → pak `docker compose ... --profile seed run --rm seed` (nutné přidat `SUPERADMIN_SEED_PASSWORD` do `deploy/test/.env`)
- Ztráta přístupu / transfer superadmina → manuální SQL (zdokumentovat v `reference_deploy_commands.md`)

---

## Kritické soubory

| Kategorie | Soubor |
|---|---|
| Schema | `prisma/schema.prisma:13-16` (enum), `prisma/seed.ts` |
| Auth | `src/lib/auth-guard.ts`, `src/lib/auth.ts` (session role propagace — už OK), `src/types/next-auth.d.ts` |
| Schemas | `src/schemas/user.ts` |
| Server actions — role | `src/actions/users.ts` (createUser/updateUser/delete/deactivate) |
| Server actions — audit | `src/actions/audit.ts`, `src/actions/field-config.ts`, `src/actions/auth.ts`, `src/actions/users.ts:resendActivationEmail` |
| API route | `src/app/api/orders/[slug]/pdf/route.ts` |
| Admin UI | `src/app/admin/layout.tsx`, `src/app/admin/admin-nav.tsx`, `src/app/admin/audit-log/page.tsx`, `src/app/admin/users/*.tsx` |
| Audit lib | `src/lib/audit.ts` (rozšířené typy) |
| i18n | `messages/{cs,en,de}.json` |
| Docs | `CLAUDE.md` |

---

## Verifikace

Po implementaci:

1. `pnpm typecheck && pnpm lint` — OK
2. `pnpm db:push` lokálně — enum rozšíří bez destrukce
3. `SUPERADMIN_SEED_PASSWORD=... pnpm db:seed` — vytvoří `superadmin@boss.local`
4. Ručně v UI:
   - **admin session**: `/admin/audit-log` → 403/redirect; v nav link chybí; v user create/edit nemá option `superadmin`; v seznamu `/admin/users` nevidí žádného superadmina
   - **superadmin session**: `/admin/audit-log` → načte se; sloupec času v tabulce zobrazuje vteřiny (DD.MM.YYYY HH:MM:SS); v seznamu `/admin/users` vidí všechny včetně sebe
   - admin zkusí editovat superadmin usera přes přímé ID → rejected na server action ("Superadmina lze upravit jen jako superadmin")
   - admin vytvoří nového user/admin → záznam v audit logu
   - superadmin upraví Validaci hodnot → záznam v audit logu s before/after diffem
   - nový user aktivuje účet → audit záznam `user.activate`
   - user si vyžádá reset hesla → audit záznam `user.password-reset-request`
   - user stáhne PDF potvrzené objednávky poprvé (jazyk CS) → záznam `order.generate-pdf`; druhé stažení stejného jazyka → žádný nový záznam
5. Test prostředí (po svolení deploy): stejné kroky na `test.objednavkypiva.cz`

---

## Edge cases / poznámky

- **Admin edituje superadmin usera přes API** (přímo s jeho ID): blokované v `updateUser/deactivateUser/deleteUser` server action
- **Superadmin sám sobě změní roli přes UI**: Zod schema přijímá jen `admin|user`, takže superadmin → admin downgrade by technicky prošel — ale admin superadmina v seznamu nevidí, takže toto je single-use scenario (superadmin by sebe musel vědomě edit a vybrat `admin`). Nebudeme proti tomu zvlášť chránit; pokud uživatel udělá, získá zpět přes DB.
- **Failed password reset request na neexistující email**: nelogovat (ochrana proti email enumeration); aktuální `auth.ts:62-64` už vrací success "always" — audit jen po reálném DB updatu
- **ARES cache upsert v `/api/ares/[ico]`**: nepřidáváme (není to admin akce, jen technická cache)
- **User preferences** (`setLocale`, `setTheme`, `updateOrdersColumns`): nelogujeme — UI state, ne administrativní akce (mimo rozsah požadavku)
