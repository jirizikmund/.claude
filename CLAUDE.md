# Globální preference

## Git commit messages

- Nikdy nepřidávat zmínky o Claude Code do commit messages
- Nepoužívat footer "Generated with Claude Code" ani "Co-Authored-By: Claude"
- Pokud není specifikováno číslo tasku, používat conventional commits formát (feat:, fix:, docs:, chore:, refactor:, test:, style:, perf:, ci:, build:)

## Git historie

- Nikdy bez potvrzení uživatele neměnit git historii (žádný amend, rebase, force push apod.)

## Package manager

- U všech nových projektů používat pnpm (ne npm/yarn)

## NPM publishing

- Nespouštět npm login/publish přímo - nefunguje interaktivní přihlášení
- Pouze nabídnout uživateli správný příkaz, který si spustí sám
- Vždy nejdřív nabídnout `--dry-run` pro kontrolu, pak teprve skutečnou publikaci

## Soubory plánů v memory

- Název souboru vždy začíná číslem tasku: `XXXX-popis.md`

## Verzování

- Při vytváření releasu se VŽDY zeptat na typ bumpu: patch / minor / major / only build
- Bump verze provést ve vlastním commitu
- Commit message ve formátu `v1.2.0` (jen verze, nic jiného)
- Zároveň aplikovat git tag s číslem buildu za poslední tečkou (např. `git tag v1.2.0.123`)

## Projektová dokumentace

Sdíleno s agentským strojem přes import (single-source v `agent-dotclaude/rules/`):

@~/Projects/@d4works/agent-dotclaude/rules/documentation.md
