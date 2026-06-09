# Přeformulovat `account.missingRoles` ve všech jazycích

## Context

Hláška `account.missingRoles` se zobrazuje v `src/screens/ScreenTransport/index.tsx:230` (`{t('account.missingRoles')}`) když má uživatel zaflagovaný `STORE.app.useHasMissingRoles()`. Aktuální texty jsou poměrně dlouhé, formálně suché a opakují slovo „dispečink/dispatch/Disposition" dvakrát. Cílem je krátká, věcná jednověta varianta (vybraná uživatelem) — stejný význam, méně textu, jasná výzva k akci.

## Aktuální texty (`src/i18n/locales/*.json`, řádek 3 v každém)

- **cs**: „Váš účet čeká na schválení ze strany dispečinku, abyste mohli aplikaci používat. Pro více informací se prosím obraťte na dispečink."
- **en**: „Your account is awaiting approval from the dispatch to be able to use the app. Please contact the dispatch for more information."
- **sk**: „Váš účet čaká na schválenie zo strany dispečingu, aby ste mohli aplikáciu používať. Pre viac informácií kontaktujte prosím dispečing."
- **de**: „Ihr Konto muss noch von der Disposition freigeschaltet werden, damit Sie die App nutzen können. Bitte wenden Sie sich an die Disposition, um weitere Informationen zu erhalten."
- **uk**: „Ваш обліковий запис очікує на затвердження диспетчерською службою, щоб ви могли користуватися додатком. За додатковою інформацією зверніться до диспетчерської служби"

## Navrhované texty

Stejná struktura ve všech jazycích: jedna věta o stavu + jedna krátká výzva.

- **cs**: „Váš účet čeká na schválení dispečinkem. Pro přístup ho kontaktujte."
- **en**: „Your account is awaiting dispatch approval. Please contact your dispatch to gain access."
- **sk**: „Váš účet čaká na schválenie dispečingom. Pre prístup ho kontaktujte."
- **de**: „Ihr Konto wartet auf die Freigabe durch die Disposition. Bitte kontaktieren Sie diese für den Zugang."
- **uk**: „Ваш обліковий запис очікує на затвердження від диспетчерської служби. Для доступу зверніться до неї."

### Validace překladů

- **Terminologie konzistentní s existujícím slovníkem souboru:** `dispečink/dispatch/dispečing/Disposition/диспетчерська служба` zachovány.
- **Formální oslovení**: cs/sk vykání, de „Sie", uk „ви/вашого/зверніться" (formální, podle paměťové poznámky o vykání v UK).
- **Pluralizace / interpolace**: text neobsahuje `{{var}}` ani plural keys → není co přenést.
- **Slovosled / pády**:
  - sk „dispečingom" (instrumentál „kým") oproti aktuálnímu „zo strany dispečingu" — kratší, idiomatičtější.
  - de „durch die Disposition" (Akkusativ s `durch`) → spisovné a přirozené.
  - uk „від диспетчерської служби" (genitiv s `від`) místo aktuálního instrumentalu „диспетчерською службою" — přirozenější vazba s „очікує на затвердження".
  - „Pro přístup ho kontaktujte" — `ho` se gramaticky vztahuje k mužskému „dispečink"; ve sk stejně k „dispečing".
  - de „diese" (Demonstrativpronomen, fem.) odkazuje na předchozí „die Disposition" → jednoznačné, vyhne se opakování slova.
  - uk „до неї" (Gen. fem.) odkazuje na předchozí „диспетчерська служба".
- **Diakritika**: zachována ve všech jazycích.

## Plánovaná editace

Změnit hodnotu klíče `account.missingRoles` na řádku 3 v souborech:

- `src/i18n/locales/cs.json`
- `src/i18n/locales/en.json`
- `src/i18n/locales/sk.json`
- `src/i18n/locales/de.json`
- `src/i18n/locales/uk.json`

Žádné jiné klíče se nemění; struktura JSON zůstává.

## Commit

Jediný commit s prefixem TMS-478 (probíhá tracking času):

```
[TMS-478] Reword account.missingRoles message
```

## Verification

1. Spustit aplikaci se simulovaným `hasMissingRoles=true` (např. `STORE.app.setHasMissingRoles(true)` přes debug nebo nepotvrzený AD účet) a ověřit, že hláška na `ScreenTransport` vypadá v každém jazyku přirozeně a vejde se do layoutu.
2. Přepnout `appLocale` mezi cs/en/sk/de/uk a vizuálně zkontrolovat zalomení.
3. (TS check není nutný — JSON.)
