---
name: Ikony — barvy podle role v UI, ne paušálně Colors.icon
description: Sémantická volba barvy ikony v redesignovaných obrazovkách závisí na roli ikony, ne na výchozím "icon" tokenu
type: feedback
originSessionId: e36aacaa-c108-4340-b116-23898ccd1eef
---
V mFTL redesignu **Colors.icon NENÍ univerzální barva pro všechny ikony**. Ve Figmě se ikony barvitě liší podle role.

| Role / kontext | Barva ve Figmě (dark) | Sémantický token |
|---|---|---|
| Ikona v "User card" / "Dispatcher card" panelu (avatar) | `#979797` (grey-300) | `Colors.text.support` |
| Pravá akční ikona v panelu (LocalPhone, atd.) | `#ACACAC` (grey-200) | `Colors.text.secondary` |
| ListItem leftIcon (informační, např. Dialpad/Pattern/Fingerprint) | `#FFFFFF` | `Colors.text.primary` |
| ListItem chevron-right / chevron-forward | `#979797` (grey-300) | `Colors.text.support` |
| Ikona statusu (warning/success/error) | dle stavu | `Colors.state.{warning|success|error}.primary` |
| Ikona uvnitř primary buttonu | bílá | `Colors.text.primary` |
| Initials v avataru (text) | šedá | `Colors.text.support` |

**Why:** Při tvorbě DispatcherCard jsem implicitně nastavil `Colors.icon` (= bílá v dark) na headset i phone ikonu. Figma ale používá pro panely šedší ikony, aby barevně nekonkurovaly titulu. Tento "wrong default" se může objevit jinde, kdykoli kopíruju vzor a nezkontroluju Figma SVG fill.

**How to apply:**
- **Před nastavením barvy ikony si vždy vzpomenout na roli ikony** — je to dekorativní/podpůrná (panel avatar, chevron) nebo informační (leftIcon ve výběru, tlačítko)?
- Pro ověření exaktní barvy: stáhnout SVG z Figma export URL (`https://www.figma.com/api/mcp/asset/<id>`) přes WebFetch a podívat se na fill — `var(--fill-0, #XXXXXX)` fallback bývá rendered hex pro daný režim. Pro chevron může být fallback ze světlého režimu — pak je třeba zkusit screenshot.
- Pokud Figma ikona má fill `#979797` → `Colors.text.support`. `#ACACAC` → `Colors.text.secondary`. `#FFFFFF` → `Colors.text.primary`.
- `Colors.icon` použít jen pro výslovně "icon-role" elementy bez panelu — typicky standalone ikony bez kontextu (toolbar, etc.).
