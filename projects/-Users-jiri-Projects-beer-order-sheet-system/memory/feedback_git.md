---
name: Git pravidla
description: Nikdy neamendovat commity bez povolení. Commitovat všechny úpravy v logických celcích pro čitelnou historii.
type: feedback
---

Nikdy neamendovat commity bez explicitního povolení uživatele. Commitovat všechny úpravy v logických celcích.

**Why:** Uživatel chce přehlednou a čitelnou git historii. Amend může ztratit kontext předchozích commitů.

**How to apply:** Každá logická změna = nový commit. Při chybě udělat nový opravný commit, ne amend. Vždy se zeptat před jakoukoliv operací měnící historii.
