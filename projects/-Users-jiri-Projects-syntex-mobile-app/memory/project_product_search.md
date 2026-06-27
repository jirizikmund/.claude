---
name: project-product-search
description: Planned task — turn the search input on the Products tab into a real inline filter of the product menu instead of redirecting to a generic search screen.
metadata: 
  node_type: memory
  type: project
  originSessionId: 5b46e043-fa27-4e27-82e1-f1268d186cb6
---

Úkol (zadán a **implementován 2026-06-19**): Na záložce **Produkty** je vyhledávací input. Současné chování — kliknutí na něj **přesměruje na obecnou vyhledávací obrazovku**, což nedává smysl. Cíl: input se má chovat jako **skutečný vyhledávací input** a při psaní rovnou **filtrovat položky v produktovém menu**.

**Why:** Redirect na samostatnou obecnou search obrazovku je matoucí; uživatel očekává, že psaní do inputu rovnou zúží produktové menu.

**Hotovo:** Zvolena varianta A — lokální filtr stromu kategorií podle názvu (bez diakritiky), jen na záložce Produkty; homepage modal i WidgetSearch beze změny (dál redirect). Plný popis chování i implementace je v `docs/features/products.md` (to je teď zdroj pravdy, viz [[feedback-keep-docs-updated]]).
