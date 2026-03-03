# Rozšíření statusline o cenu, řádky a git info

## Context
Uživatel chce do Claude Code statusline přidat: cenu session ($), počet přidaných/odebraných řádků a git větev se stavem (dirty/clean).

## Soubor k úpravě
- `/Users/jiri/.claude/statusline-command.sh`

## Plán změn

Rozšířit skript o tři nové sekce:

1. **Cena session** — z `cost.total_cost_usd`, formát `$0.12`
2. **Řádky +/-** — z `cost.total_lines_added` a `cost.total_lines_removed`, formát `+42/-7`
3. **Git větev + stav** — z `git branch --show-current` + `git status --porcelain` pro detekci dirty stavu, formát `master` nebo `master*`

### Výsledný vzhled statusline

```
jiri eflight  master*  [Opus 4.6]  +42/-7  $0.12  ctx:8%
```

- `jiri` — zelená
- `eflight` — bílá
- `master*` — žlutá (hvězdička pokud dirty)
- `[Opus 4.6]` — červená
- `+42/-7` — zelená/červená
- `$0.12` — žlutá
- `ctx:8%` — tlumená

### Implementace

Přidat do skriptu extrakci nových hodnot z JSON:
```bash
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
added=$(echo "$input" | jq -r '.cost.total_lines_added // empty')
removed=$(echo "$input" | jq -r '.cost.total_lines_removed // empty')
```

Git info přímo ze shellu:
```bash
branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
dirty=$(git -C "$cwd" status --porcelain 2>/dev/null)
```

Sestavit výstup s ANSI barvami v jednom `printf`.

## Ověření
- Spustit Claude Code a ověřit, že statusline zobrazuje všechny nové údaje
- Ověřit v git repozitáři i mimo něj (git info se nezobrazí mimo repo)
