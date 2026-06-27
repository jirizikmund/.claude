---
name: nespou-t-t-vizu-ln-inspector-z-vlastn-iniciativy
description: "eflight-visual-inspector (ani jinou browser inspekci) nikdy nespouštět bez explicitního pokynu uživatele — ani po změnách, ani pro diagnostiku bugů"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 73d1a7c2-5810-4043-826c-3ea1730d18a0
---

eflight-visual-inspector agenta (Playwright inspekci aplikace) NIKDY nespouštět z vlastní
iniciativy — ani po změnách kódu, ani jako diagnostický krok při hledání bugu (potvrzeno
11.6.2026, kdy uživatel zamítl spuštění inspektoru navržené pro debug timeline).

**Why:** Uživatel preferuje provádět vizuální kontrolu ručně v prohlížeči; automatická
inspekce je pomalá a zbytečná. Platí to univerzálně, ne jen pro kontroly po změnách.

**How to apply:** Inspekci spouštět pouze tehdy, když o ni uživatel explicitně požádá. Po změnách
UI stačí tsc + eslint. Při diagnostice bugů místo inspekce: analýza kódu, dotaz na uživatele
(co vidí v konzoli/network), nebo požádat o screenshot.
