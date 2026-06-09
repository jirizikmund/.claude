---
name: Figma soubory pro mFTL design
description: Aktivní Figma soubory s design systémem a obrazovkami pro redesign mFTL aplikace
type: reference
originSessionId: e36aacaa-c108-4340-b116-23898ccd1eef
---
**Aktivní soubor (TMS-556+):** mFTL-app — fileKey `UfAztynGtHHU9AdWfLUb70`
- URL pattern: `https://www.figma.com/design/UfAztynGtHHU9AdWfLUb70/mFTL-app?node-id=<node>`
- Obsahuje obrazovky redesignu (Podpora node `1056:6650`, atd.)
- Použít `mcp__plugin_figma_figma__get_design_context` s `fileKey="UfAztynGtHHU9AdWfLUb70"` a node ID z URL

**Předchozí soubor (TMS-522 foundation):** mFTL-DEV — fileKey `jVCGflP7L9HWx41BVyguQo`
- Použit pro design system foundation: Button, TabSwitch komponenty
- Některé starší redesign frame mohou tam ještě být

Pokud uživatel pošle Figma URL bez kontextu, extrahovat fileKey z URL (`figma.com/design/<fileKey>/...`) a node-id (převést `-` na `:` u node ID, např. `1056-6650` → `1056:6650`).
