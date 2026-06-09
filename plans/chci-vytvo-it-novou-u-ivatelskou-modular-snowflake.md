# Plán: Netdata monitoring (Cloud free tier) — integrace do wizardu a deploy.sh

## Context

Dnes nás málem dohnal incident: disk na produkčním VPS byl 92 % zaplněný kvůli akumulaci nepoužívaných Docker images. Problém byl odhalen jen náhodně z Active24 panelu. Také nám rostou zombie procesy z Puppeteeru. Bez monitoringu by příští incident skončil výpadkem.

**Cíl**: pasivní monitoring přes **Netdata + Netdata Cloud free tier** s emailovými alerty na disk, RAM, container restarts, zombie procesy a Postgres health. Pro **kompletní integraci do existujícího setup procesu** je nutné:

- Setup Netdata být součástí `pnpm vps:bootstrap` wizardu (idempotentní, re-run safe, state persistence)
- `deploy.sh` při každém deployi posílat **deployment marker** do Netdaty, aby spike v grafech (RAM, CPU) měl viditelnou kotvu

Jakmile fresh VPS projde wizardem od nuly, Netdata běží + claimed v Cloudu + emailové alerty fungují, **bez ručních kroků na VPS**.

## Architektura

```
┌──────────────────────────────────────┐         outbound TLS (ACLK)
│  VPS (objednavkypiva.cz)             │         + claim token
│  ┌────────────────────────────────┐  │       ┌──────────────────────────────┐
│  │  netdata daemon                │──┼──────▶│  app.netdata.cloud           │
│  │   ├ system collectors          │  │       │  Space "BOSS"                │
│  │   ├ cgroup collector (Docker)  │  │       │  Room "production"           │
│  │   ├ go.d/postgres collector    │  │       │  Email notif → jiri@...      │
│  │   ├ systemd-journal collector  │  │       └──────────────────────────────┘
│  │   ├ DBEngine TSDB (700 MB)     │  │
│  │   └ alerts engine              │  │
│  │  port 19999 → bind 127.0.0.1   │  │
│  └────────────────────────────────┘  │
│                                      │
│  deploy.sh konec:                    │
│   logger -t boss-deploy "..."        │ ─┐
│                                      │  │ journal collector → events tag
└──────────────────────────────────────┘  │ → annotace v dashboardu
                                          ▼
                                   "deploy: prod abc123" v timeline
```

## Soubory a změny — přehled

**Nové:**
- `scripts/setup/steps/netdata-cloud.ts` — wizard step: získat claim token + room IDs od uživatele
- `scripts/setup/steps/netdata-install.ts` — wizard step: install agent na VPS přes SSH
- `deploy/setup-netdata.sh` — idempotentní instalační skript spouštěný přes SSH (`bash -s` z wizardu)

**Upravené:**
- `scripts/setup.ts` — přidat 2 nové stepy do sekvence
- `scripts/setup/state.ts` — rozšířit `SetupState` o `netdata?` field + 2 nové `StepName`
- `deploy/deploy.sh` — `logger -t boss-deploy` event před závěrečným logem
- `.gitignore` — pokud vznikne další state, ale `scripts/.setup-state.json` už ignored

**Nezměněné:**
- `deploy/bootstrap-vps.sh` — Netdata install **neteče přes bootstrap**, ale přes vlastní step. Důvody: separace concerns, možnost re-run jen Netdata setupu bez touch bootstrapu, čistší state tracking. Bootstrap dál instaluje jen base systém (Docker, ufw, swap, ...).

## 1) Pozice ve wizardu

```
... (kroky 1-13 zůstávají)
14. Bootstrap VPS                    ← existing
15. Push .env souborů na VPS         ← existing
16. Konfigurace rclone na VPS        ← existing
17. GHCR docker login na VPS         ← existing
18. Spuštění Caddy stacku            ← existing
19. První deploy — Test stack        ← existing
20. Test DB — seed nebo restore      ← existing
21. První deploy — Production stack  ← existing
22. Production DB — seed nebo restore← existing
23. Smoke test                       ← existing
24. Netdata Cloud setup              ← NOVÝ (token + room IDs od uživatele)
25. Netdata install na VPS           ← NOVÝ (SSH install + claim + config)
26. Active24 snapshot                ← bývalý 24, nyní 26
```

**Proč až po smoke testu, ne před bootstrap?**

- Postgres collector potřebuje běžící DB (existuje až po krocích 20+22)
- Cgroup metriky containerů mají smysl, až když containery běží
- Pokud Netdata claim selže (špatný token, Cloud down), neblokujeme launch produkce
- Fresh VPS bez Netdaty může běžet a obsluhovat — Netdata je add-on, ne dependency

Split na **dva stepy** (Cloud setup + Install):
- Krok 24: jen text instrukce + `inquirer` prompt na token. Žádná SSH akce.
- Krok 25: spustí `setup-netdata.sh` přes SSH s tokenem ze state.

Důvod splitu: kdyby uživatel přerušil v půli (Ctrl-C během Cloud sign-upu), re-run wizardu nepokouší zbytečně instalovat agenta s prázdným tokenem.

## 2) `scripts/setup/steps/netdata-cloud.ts` — krok 24

Pattern stejný jako `sentry.ts`. Pseudo:

```typescript
export async function runNetdataCloud(state: SetupState): Promise<void> {
  const decision = await stepGate(state, 'netdata-cloud');
  if (decision === 'skip') return;

  instruction([
    'Vytvoř Netdata Cloud Space (free tier, není potřeba kreditka):',
    '',
    '  1. https://app.netdata.cloud → Sign up (Google login s jiri@d4works.cz)',
    '  2. Create Space → název "BOSS"',
    '  3. Create Room → název "production"',
    '  4. V Space → Settings → "Connect Nodes":',
    '     - zkopíruj CLAIM TOKEN (začíná "eyJh..." nebo podobně)',
    '     - zkopíruj ROOM IDs (UUID, čárkou oddělené pokud více)',
    '  5. V Space → Settings → Notifications → Add → Email',
    '     - Recipients: jiri@d4works.cz',
    '     - Severity: Critical + Warning + Clear',
    '     - Test → "Send test notification" → ověř doručení',
    '',
    'Token a room IDs jsou citlivé — uloží se do scripts/.setup-state.json (mode 0600).',
  ]);

  const claimToken = await password({ message: 'Netdata claim token:', mask: '*', validate: ... });
  const roomIds = await input({ message: 'Room IDs (čárkou oddělené):', validate: ... });

  state.netdata = { claimToken: claimToken.trim(), roomIds: roomIds.trim() };
  saveState(state);

  finishStep(state, 'netdata-cloud');
}
```

Validace:
- Claim token: non-empty, > 20 znaků (formát se mění mezi verzemi Cloudu, neválidovat regex)
- Room IDs: non-empty, regex pro UUID (čárka volitelná)

## 3) `deploy/setup-netdata.sh` — VPS-side instalační skript

Idempotentní bash skript. Spouští se přes `ssh root@VPS 'bash -s' < setup-netdata.sh` z wizardu. Skript dostane parametry přes env vars:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Required env (od wizardu):
: "${NETDATA_CLAIM_TOKEN:?required}"
: "${NETDATA_ROOM_IDS:?required}"
: "${POSTGRES_PROD_PASSWORD:?required}"
: "${POSTGRES_TEST_PASSWORD:?required}"
: "${POSTGRES_USER:?required}"
: "${POSTGRES_DB:?required}"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }

# 1. Install (idempotentní — kickstart re-run je no-op pokud už agent běží)
log "Install Netdata agent (kickstart)"
if ! command -v netdata >/dev/null 2>&1; then
    wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh
    sh /tmp/netdata-kickstart.sh \
        --claim-token "$NETDATA_CLAIM_TOKEN" \
        --claim-rooms "$NETDATA_ROOM_IDS" \
        --claim-url https://app.netdata.cloud \
        --stable-channel \
        --disable-telemetry \
        --non-interactive
else
    # už nainstalovaný → jen claim (idempotentní)
    netdata-claim.sh -token="$NETDATA_CLAIM_TOKEN" -rooms="$NETDATA_ROOM_IDS" -url=https://app.netdata.cloud || true
fi

# 2. Bind dashboard na localhost
log "Restrict web dashboard to 127.0.0.1"
mkdir -p /etc/netdata
cat > /etc/netdata/netdata.conf.d/web-bind.conf <<EOF
[web]
    bind to = 127.0.0.1
EOF

# 3. Postgres user + collector config
log "Create read-only Postgres user 'netdata' on prod + test"
NETDATA_PG_PASS_PROD=$(openssl rand -hex 16)
NETDATA_PG_PASS_TEST=$(openssl rand -hex 16)

create_pg_user() {
    local container="$1" pass="$2"
    docker exec -i "$container" psql -U "$POSTGRES_USER" "$POSTGRES_DB" <<SQL
DO \$\$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'netdata') THEN
        CREATE ROLE netdata WITH LOGIN PASSWORD '$pass';
        GRANT pg_monitor TO netdata;
        GRANT CONNECT ON DATABASE "$POSTGRES_DB" TO netdata;
    ELSE
        ALTER ROLE netdata WITH PASSWORD '$pass';
    END IF;
END \$\$;
SQL
}
create_pg_user boss-prod-db "$NETDATA_PG_PASS_PROD"
create_pg_user boss-test-db "$NETDATA_PG_PASS_TEST"

# 4. Postgres collector config — connect přes Docker network 'boss-net'
log "Configure go.d/postgres.conf"
cat > /etc/netdata/go.d/postgres.conf <<EOF
jobs:
  - name: boss_prod
    dsn: postgres://netdata:$NETDATA_PG_PASS_PROD@boss-prod-db:5432/$POSTGRES_DB?sslmode=disable
  - name: boss_test
    dsn: postgres://netdata:$NETDATA_PG_PASS_TEST@boss-test-db:5432/$POSTGRES_DB?sslmode=disable
EOF
chmod 0640 /etc/netdata/go.d/postgres.conf
chown root:netdata /etc/netdata/go.d/postgres.conf

# 5. Připojit Netdata k boss-net (aby viděla DB containers)
log "Attach netdata to boss-net Docker network"
# Netdata běží na host, ne v containeru → přístup k boss-net přes
# DNS to nejde. Místo toho použijeme bridge IP DB containers,
# nebo Netdata pustit jako container.
# DECISION: Netdata zůstává host-installed (kickstart default).
# Postgres exposeneme na 127.0.0.1 v compose:
#   ports: ["127.0.0.1:5432:5432"]  (prod), 5433 (test)
# DSN se pak změní na 127.0.0.1:5432 / :5433.
# (Skutečný DSN config viz krok 4 výše — host: 127.0.0.1)

# 6. systemd-journal collector pro deployment markers
log "Enable systemd-journal collector"
# Defaultně už zapnutý. Konfigurace ne-trivální → ponechat default.
# Deployment events z 'logger -t boss-deploy' se zobrazí v Logs sekci.

# 7. Restart + ověření
log "Restart netdata"
systemctl restart netdata
sleep 3
systemctl is-active netdata >/dev/null || { echo "Netdata neběží — viz: journalctl -u netdata"; exit 1; }

log "Setup hotov. Cloud dashboard: https://app.netdata.cloud"
```

**Pozn. ke kroku 5 (Postgres connectivity):**

Aktuálně Postgres v compose není exposed na host (jen `boss-net`). Dvě cesty:
- **(A)** Přidat `ports: ["127.0.0.1:5432:5432"]` do `deploy/prod/docker-compose.yml` a `["127.0.0.1:5433:5432"]` do test → Netdata se připojí přes 127.0.0.1
- **(B)** Spustit Netdatu jako Docker container ve `boss-net`

Volím **(A)** — kickstart instaluje Netdatu na host (ne container), to je doporučený způsob (lepší přístup k cgroupům, /proc, atd.). Bind na 127.0.0.1 je bezpečné — z internetu nedostupné, jen pro lokální procesy.

Compose změna je trivial, ale zasahuje deploy artefakt → musí se revize. Plán: změnit compose v rámci tohoto úkolu, deployovat, a teprve pak Netdata install funguje.

## 4) `scripts/setup/steps/netdata-install.ts` — krok 25

Pattern jako `bootstrap.ts`. Pseudo:

```typescript
export async function runNetdataInstall(state: SetupState): Promise<void> {
  const decision = await stepGate(state, 'netdata-install');
  if (decision === 'skip') return;

  if (!state.vpsIp) throw new Error('Missing vpsIp');
  if (!state.netdata?.claimToken) throw new Error('Missing netdata token — re-run step 24');
  if (!state.secrets?.prod || !state.secrets?.test) throw new Error('Missing DB passwords');

  const scriptPath = join(process.cwd(), 'deploy', 'setup-netdata.sh');
  const scriptContent = readFileSync(scriptPath, 'utf8');

  info(`Instaluju Netdata agenta na root@${state.vpsIp}...`);
  info('Trvá ~3-5 min (download + install + claim + restart).');

  const env = {
    ...process.env,
    NETDATA_CLAIM_TOKEN: state.netdata.claimToken,
    NETDATA_ROOM_IDS: state.netdata.roomIds,
    POSTGRES_USER: 'boss', // z .env, hardcoded podle convention
    POSTGRES_DB: 'boss',
    POSTGRES_PROD_PASSWORD: state.secrets.prod.postgresPassword,
    POSTGRES_TEST_PASSWORD: state.secrets.test.postgresPassword,
  };

  const result = spawnSync('ssh', [
    '-i', getActiveSshKey(),
    '-o', 'BatchMode=yes',
    '-o', 'StrictHostKeyChecking=accept-new',
    '-o', 'SendEnv=NETDATA_CLAIM_TOKEN NETDATA_ROOM_IDS POSTGRES_*',
    `root@${state.vpsIp}`,
    'bash -s'
  ], {
    input: scriptContent,
    stdio: ['pipe', 'inherit', 'inherit'],
    env,
  });

  if (result.status !== 0) {
    throw new Error(`Netdata install selhal (exit ${result.status})`);
  }

  success('Netdata běží + claimed v Cloudu.');
  info('Ověř na https://app.netdata.cloud — node "objednavkypiva" v Roomu "production".');
  finishStep(state, 'netdata-install');
}
```

**Pozn.** k env vars přes SSH: defaultní sshd_config nepouští `SendEnv`. Bezpečnější je inline expand v kickstart skriptu — ale pak token leakuje do `ps aux` během běhu skriptu. Nejčistší cesta: expandnout env vars **client-side v Node** přímo do script content přes template substitution před `bash -s`. Tj. v `netdata-install.ts`:

```typescript
const scriptWithEnv = scriptContent
  .replace(/\$\{NETDATA_CLAIM_TOKEN\}/g, state.netdata.claimToken)
  .replace(/\$\{NETDATA_ROOM_IDS\}/g, state.netdata.roomIds)
  // atd.
```

A v `setup-netdata.sh` zaměnit `${NETDATA_CLAIM_TOKEN}` placeholder za skutečnou expanzi (template-style). Token tak nikdy není env var — žije v memory wizardu, šifrovaně přes SSH tunel, na VPS jen v argv kickstart skriptu (krátkodobě).

## 5) `scripts/setup/state.ts` — rozšíření

```typescript
export type StepName =
  | ...existující...
  | 'netdata-cloud'
  | 'netdata-install'
  | 'snapshot-prompt';

export interface SetupState {
  ...existující...
  netdata?: {
    claimToken: string;
    roomIds: string;
  };
}
```

## 6) `deploy/deploy.sh` — deployment marker

Po `Prune unused Docker images` (řádek 93-94 — už dnes přidáno, ještě necommitnuto), před `Deploy of '$STACK' complete.`:

```bash
log "Notify Netdata about deployment"
# logger → journald → Netdata systemd-journal collector → annotace v Cloud dashboardu.
# Tag 'boss-deploy' ti umožní filtrovat events v Logs sekci.
COMMIT=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
logger -t boss-deploy "deployed stack=$STACK commit=$COMMIT" || true
```

`|| true` — pokud `logger` chybí (nikdy), deploy se nepřeruší. Jednoduché, nezávislé na Netdata běhu.

V Cloud dashboardu se objeví v **Logs** sekci jako filtrable event. Lze taky vytvořit custom alert "alert pokud žádný `boss-deploy` event > 7 dní" → upozorníš se, že produkce se dlouho nedeployuje.

## 7) Compose změny — port mapping pro Netdata Postgres collector

`deploy/prod/docker-compose.yml` u service `db`:
```yaml
  db:
    ...
    ports:
      - "127.0.0.1:5432:5432"
```

`deploy/test/docker-compose.yml` u service `db`:
```yaml
  db:
    ...
    ports:
      - "127.0.0.1:5433:5432"
```

Bind na 127.0.0.1 je nutný — bez něj by Postgres byl exposed na 0.0.0.0:5432 a kdokoli z internetu by mohl zkoušet brute-force. UFW v bootstrap-vps.sh defaultně blokuje vše krom 22/80/443, takže by to bylo OK i bez bindu, ale belt-and-suspenders je správně.

## 8) Verifikace end-to-end

Po dokončení `pnpm vps:bootstrap` (nebo re-runu krátkých kroků 24+25 na existujícím VPS):

1. **Wizard state**: `cat scripts/.setup-state.json | jq .netdata` → `{ claimToken: "...", roomIds: "..." }` přítomný
2. **VPS daemon běží**: `ssh root@objednavkypiva.cz 'systemctl is-active netdata'` → `active`
3. **Cloud claim**: v `app.netdata.cloud` Room `production` vidím node `objednavkypiva` jako Live (zelený dot)
4. **Lokální dashboard zavřený zvenčí**: `curl --connect-timeout 5 http://81.95.108.121:19999` z lokálu → connection refused / timeout
5. **System metriky**: dashboard ukazuje disk/RAM/CPU/network grafy s 1s update rate
6. **Docker containery**: sekce "Containers" → vidím `boss-prod-app`, `boss-prod-db`, `boss-test-app`, `boss-test-db`, `boss-caddy` s per-container CPU/RAM
7. **Zombie metrika**: System → Processes → graf zobrazuje aktuální zombie count (~19+, po pozdějším `init: true` fixu spadne na 0)
8. **Postgres metriky**: sekce "PostgreSQL" → connections, db size, queries/s pro `boss_prod` i `boss_test` joby
9. **Email alert smoke test**: `app.netdata.cloud` → Settings → Notifications → "Send test notification" → email v inboxu do 1 min
10. **Deployment marker**: spustit `pnpm deploy:test` → po dokončení v Cloud dashboardu **Logs** sekce → filtr `tag=boss-deploy` → vidím event "deployed stack=test commit=abc1234"
11. **Wizard re-run idempotence**: spustit `pnpm vps:bootstrap` znovu, potvrdit "skip" pro všechny pre-Netdata kroky → wizard přejde rovnou na krok 24 → potvrdit "skip" pro 24 → přejde na 25 → potvrdit "skip" → na 26 (snapshot)
12. **Disk usage Netdaty po 24 h**: `du -sh /var/cache/netdata/dbengine/` → ~30-50 MB (full ~700 MB při tier 2 saturaci za pár měsíců)

## 9) Fail modes a recovery

| Problém | Recovery |
|---|---|
| Cloud claim selže ("token expired") | Re-run kroku 24 → vygenerovat fresh token v Cloudu → re-run 25 |
| Kickstart fails na Ubuntu native package | Auto-fallback na static binary (`/opt/netdata/`) — nic nedělat |
| Postgres collector hlásí "could not connect" | Zkontrolovat `ports:` v compose, restartovat `db` container, restart netdata |
| Email z Cloudu padá do spamu | Mark "není spam" v Gmailu jednou; Cloud používá `noreply@netdata.cloud` |
| `logger -t boss-deploy` nefunguje | Verify `journalctl -t boss-deploy` na VPS; pokud prázdné, problém v rsyslog/journald |
| Cloud dashboard "node offline" po reboot | Auto-restart by měl proběhnout (`systemctl enable netdata` v kickstart); ověřit `systemctl status netdata` |

## 10) Pořadí dnešních akcí (návaznost)

1. **Tento plán** → schválit → implementace (Netdata setup + wizard stepy + deploy marker)
2. **Po nasazení Netdaty na VPS** → vidíme aktuální zombie count (~20+) jako baseline
3. **`init: true` fix v compose** (zombies) → restart containerů → v Netdata dashboardu real-time spadne na 0 = vizuální verifikace fixu
4. **Commit + push všech změn** (deploy.sh prune, init: true, port mapping, wizard stepy)
5. **Volitelně v dalších dnech**: UptimeRobot pro external availability check, custom Netdata alerty na business metriky

## 11) Standalone usage — `pnpm vps:netdata` na běžícím VPS

**Use case**: VPS už dávno běží (po wizardu nebo třeba po manuálním deployi). Nechci znova procházet 26 kroků wizardu jen kvůli Netdatě. Chci jednorázový command.

**Řešení**: nový npm script + entry point.

### `scripts/setup-netdata.ts` (nový soubor)

Tenké entry point, které vyrenderuje jen 2 stepy ze wizardu:

```typescript
// pnpm vps:netdata — standalone Netdata install pro existující VPS.
// Nepotřebuje kompletní wizard state; když chybí, doplní values z .env / promptu.

import { color, header, info } from './setup/ui';
import { loadState, saveState, type SetupState } from './setup/state';
import { setActiveSshKey } from './setup/ssh-helpers';
import { runNetdataCloud } from './setup/steps/netdata-cloud';
import { runNetdataInstall } from './setup/steps/netdata-install';
import { hydrateStateForStandalone } from './setup/standalone-hydrate';

async function main(): Promise<void> {
  console.log(color('  BOSS — Netdata setup\n', 'bold'));

  const state = loadState();
  if (state.operatorSshKey?.privatePath) setActiveSshKey(state.operatorSshKey.privatePath);

  // Pokud state je prázdný (žádný předchozí wizard run), naplň z .env + interaktivních dotazů.
  await hydrateStateForStandalone(state);
  saveState(state);

  header('1', 'Netdata Cloud setup');
  await runNetdataCloud(state);

  header('2', 'Netdata install na VPS');
  await runNetdataInstall(state);

  console.log(color('\n  ✨ Netdata běží.\n', 'green'));
}

main().catch((err) => { console.error(err); process.exit(1); });
```

### `scripts/setup/standalone-hydrate.ts` (nový soubor)

Pro standalone mód doplní state hodnotami, které wizard má nasbírané z předchozích kroků. Strategie:

| State field | Zdroj v standalone módu |
|---|---|
| `vpsIp` | `dig +short objednavkypiva.cz` → IP, fallback prompt |
| `operatorSshKey.privatePath` | parse `~/.ssh/config` host `boss-root`, fallback prompt |
| `secrets.prod.postgresPassword` | parse `deploy/prod/.env` field `POSTGRES_PASSWORD` |
| `secrets.test.postgresPassword` | parse `deploy/test/.env` field `POSTGRES_PASSWORD` |
| `netdata` | nedoplňovat → `runNetdataCloud` se na něj zeptá interaktivně |

Pseudo:

```typescript
export async function hydrateStateForStandalone(state: SetupState): Promise<void> {
  if (!state.vpsIp) {
    state.vpsIp = await resolveDns('objednavkypiva.cz') ?? await promptForIp();
  }
  if (!state.operatorSshKey) {
    state.operatorSshKey = parseFromSshConfig('boss-root') ?? await promptForKey();
  }
  if (!state.secrets) {
    state.secrets = {
      prod: { postgresPassword: parseEnvFile('deploy/prod/.env').POSTGRES_PASSWORD, ... },
      test: { postgresPassword: parseEnvFile('deploy/test/.env').POSTGRES_PASSWORD, ... },
    };
  }
}
```

Fallback `parseEnvFile` selže gracefully → prompt na heslo. Idempotence zachována — re-run skriptu **nepřepisuje** hodnoty, které už ve state jsou (early return kdekoliv).

**Bezpečnost**: parser .env čte jen na lokálu (developer machine), hesla nikdy nejdou přes stdout/log, putují přes SSH tunel jako template-substitued bash.

### `package.json` — nový script

```json
{
  "scripts": {
    "vps:bootstrap": "tsx scripts/setup.ts",
    "vps:netdata": "tsx scripts/setup-netdata.ts"
  }
}
```

### Re-run flow z wizardu

Pokud uživatel naopak spustí celý `pnpm vps:bootstrap` na VPS, kde Netdata už běží:
- Krok 24 (cloud): `stepGate` ukáže "Netdata Cloud již dokončen, opakovat?" → skip
- Krok 25 (install): `stepGate` ukáže totéž → skip nebo re-run (re-run je bezpečný — `setup-netdata.sh` je idempotentní)

### CLAUDE.md update

Sekci `## Příkazy` rozšířit o:
```
pnpm vps:netdata     # Standalone Netdata install na existující VPS (sdílí stepy s wizardem)
```

### Verifikace standalone módu

1. Smazat `state.netdata` ze `scripts/.setup-state.json` (simuluje "Netdata ještě nebylo nasazeno")
2. `pnpm vps:netdata` → projde dvěma stepy → uloží zpět
3. Spustit znovu → `stepGate` nabídne "skip / opakovat" → skip → exit clean
4. Smazat celé `scripts/.setup-state.json` → `pnpm vps:netdata` → `hydrateStateForStandalone` doplní z .env/DNS → projde

## 12) Co plán vědomě **nezahrnuje**

- **External availability check** (ping z venku, kdyby spadl celý VPS) — UptimeRobot doplníme jako separátní úkol, nezávislé na Netdatě
- **Loki / log aggregator** — Netdata má jen counts, fulltext logs řešíme později (až bude potřeba)
- **APM** — error rate, slow requests řeší Sentry (už nasazený)
- **Custom business alerty** (např. "0 nových objednávek za 24 h") — out-of-box pravidla pokrývají infra; business metriky doplníme později podle potřeby
- **Netdata HA / multi-node setup** — pro single VPS nemá smysl
