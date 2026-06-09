---
name: Bez automatického push a vytváření PR
description: Nikdy nepushovat (na žádnou větev, ani na master) ani nevytvářet PR bez explicitního pokynu uživatele
type: feedback
originSessionId: 4f273175-4fcf-4609-9412-9f65d25f5a3e
---
Nikdy sám od sebe nepushovat na remote — **ani na master, ani na feature větve, ani PR větve** — a nevytvářet pull requesty. Lokální commit je OK (lze revertovat), push/PR jsou viditelné akce s dosahem mimo lokální stroj.

**Speciálně push do masteru:** vyžaduje explicitní pokyn typu „pushni" / „push do masteru" / „commitni a pushni". **Vágní zelená světla jako „pokračuj", „ok", „hotovo" NEJSOU dovolení k pushi** — jsou to pokračování konverzace, ne autorizace remote operace. I když parent PR byl mergnut a fix je natural follow-up, push na master je samostatný explicitní krok.

**Why:** Uživatel mě napomenul 2× — poprvé po vytvoření hotfix PR #2683 bez souhlasu, podruhé po pushi follow-up fixu (`3873bc988`) přímo na master pod záminkou „pokračuj" (2026-05-13). Push má blast radius mimo můj stroj (team, CI, deploy), proto vyžaduje konfirmaci pokaždé.

**How to apply:** Po dokončení změn lokální commit OK. **Před každým `git push`** (jakákoliv větev) se zeptat. Před `gh pr create` se zeptat. Když uživatel řekne neurčité „pokračuj" po committech, znamená to „pokračuj v práci", ne „pushni a hotovo" — pokud chce push, řekne to explicitně.
