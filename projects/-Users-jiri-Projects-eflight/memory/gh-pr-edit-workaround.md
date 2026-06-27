---
name: gh-pr-edit-workaround
description: "gh pr edit v repu veproza/eflight padá na deprecated GraphQL projectCards — popis PR nastavovat přes REST: gh api repos/veproza/eflight/pulls/N -X PATCH -F body=@file"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 73d1a7c2-5810-4043-826c-3ea1730d18a0
---

`gh pr edit <N> --body-file …` v repu veproza/eflight selhává chybou
„GraphQL: Projects (classic) is being deprecated … (repository.pullRequest.projectCards)"
(starší gh CLI dotazuje zrušené pole).

**How to apply:** použít REST API, které projectCards nečte:

```bash
gh api repos/veproza/eflight/pulls/<N> -X PATCH -F body=@/tmp/pr-body.md
```

(`-F body=@file` načte obsah souboru; ověření: `gh api repos/veproza/eflight/pulls/<N> --jq '.body'`.)
Čtení (`gh pr list/view --json`) funguje normálně. Poprvé naraženo 12.6.2026 u PR #2757.
