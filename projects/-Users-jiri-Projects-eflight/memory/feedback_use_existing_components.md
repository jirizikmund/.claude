---
name: Používat existující UI komponenty
description: Při implementaci UI vždy preferovat hotové komponenty z src/ui/components a src/components/common
type: feedback
---

Při implementaci UI vždy defaultně používat již hotové základní komponenty z projektu.

Primární zdroj: `src/ui/components`
Sekundární zdroj: `src/components/common`

**Why:** Projekt má vlastní knihovnu komponent — používání vlastních/nových elementů místo existujících vede k nekonzistentnímu UI a zbytečné duplikaci.

**How to apply:** Před vytvářením nových UI prvků vždy nejdřív zkontrolovat, zda odpovídající komponenta již existuje v `src/ui/components` nebo `src/components/common`. Použít existující komponentu i pokud vyžaduje drobné úpravy.
