---
name: shared-build-artifacts
description: "amplify/.../flightboard/src/@eflight/shared/*.d.ts jsou build artefakty @eflight/shared — kosmetické diffy po startu dev serveru zahodit, necommitovat"
metadata: 
  node_type: memory
  type: project
  originSessionId: 73d1a7c2-5810-4043-826c-3ea1730d18a0
---

# Build artefakty @eflight/shared v amplify funkci flightboard

`@eflight/shared` se builduje přes `npm run build:shared` = tsc do `@eflight/shared/dist` +
`postbuild.js` kopie do `amplify/backend/function/flightboard/src/@eflight/shared/` (verzováno
v gitu, Lambda to potřebuje při deployi) + NAKONEC `prettier amplify/**/*.d.ts --write`.

**Why:** Start dev serveru (`npm run dev` = concurrently styles-watch + vite, port 3000) může
dist i amplify kopii přegenerovat BEZ závěrečného prettier kroku → git ukáže zdánlivé modifikace
.d.ts souborů, které jsou čistě formátovací (zalomení, uvozovky), bez věcné změny.

**How to apply:** Takové diffy do commitů nezahrnovat — zahodit `git checkout -- amplify/`.
Commitovat je jen jako součást záměrného `npm run build:shared` před deployem flightboard funkce.
