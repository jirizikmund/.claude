---
name: Nikdy neamendovat commity bez výslovného povolení
description: Zákaz git commit --amend (i --no-edit) bez explicitního pokynu uživatele
type: feedback
originSessionId: 03918468-eab2-4b0b-a5fc-eab6cfae436d
---
Nikdy nepoužívat `git commit --amend` (ani `--amend --no-edit`) bez toho, aby si to uživatel výslovně vyžádal.

**Why:** Amend přepisuje existující commit (mění hash, vyžaduje force-push, maže historii). Uživatel už mi toto porušil při opravě conditional useMemo na PR #2635 a připomněl, že globální pravidlo "nikdy neměnit git historii bez potvrzení" z `~/.claude/CLAUDE.md` platí i pro amend.

**How to apply:** Pokud je potřeba doplnit commit (fix po lintu, opravit špatně staged soubor, apod.), **vždy vytvořit nový commit**. I když je to kosmeticky horší (víc commitů v historii), je to bezpečnější — uživatel si je případně squashne sám.
