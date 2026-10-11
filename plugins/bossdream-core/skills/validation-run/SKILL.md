---
name: validation-run
description: Orquesta la corrida completa del pipeline de Document Validation para el proyecto activo. Dispara validation-check.ps1 (deterministico), decide si hace falta el agente bossdream-document-auditor para la parte semantica, y arma la tanda de preguntas (≤3) o el listado completo de errores (>3) segun el umbral de validation-rules.json. TRIGGER — la invoca /bossdream-validate.
arguments:
  - name: proyecto
    description: "slug del proyecto activo (normalmente ya viene de .claude/.active-project)"
---

# validation-run — orquestacion del gate de Document Validation

Pipeline de Document Validation. Nunca corre el agente antes que los scripts deterministas (fail-fast barato primero — mismo principio que `pipeline.ps1` de codigo).

## Proceso

1. **Localiza el proyecto activo**: lee `.claude/.active-project`; si no existe, dilo y PARA (no hay nada que confirmar).

2. **Primera pasada — deterministica**: corre `scripts/validation-check.ps1 -ProjectSlug <slug>` (sin `-SemanticVerdictsPath`). Esto ejecuta la cascada barato→caro (`validation-vale-check.ps1` → `validation-structure-check.ps1`, mas `validation-trace-check.ps1` a nivel de proyecto) y validation-check.ps1 escribe el resultado en `validation.json`. Documentos que fallan aqui quedan `blocked` — **no se invoca el agente para esos**, ya tienen razon concreta y determinista.

3. **Lee `validation.json`** tras la primera pasada:
   - Documentos en `blocked` (por vocabulario/estructura) → van directo a la lista de hallazgos, sin agente.
   - `projectChecks.TRACE` en `blocked` → hallazgo de proyecto (IDs huerfanos/fantasma), sin agente.
   - Documentos en `needs-semantic-review` cuyo `status` ANTES de esta corrida era `verified` (es decir: solo cambio el fingerprint, `validation-check.ps1` los reabre por default sin poder distinguir mecanico de semantico) → antes de sumarlos a la tanda del paso 4, pregunta al usuario si el cambio fue puramente mecanico (ej. un reemplazo de ruta que no toco contenido de negocio). Si confirma, invoca `scripts/validation-mark-mechanical.ps1 -ProjectSlug <slug> -DocPattern <ruta exacta de ese documento> -Reason <motivo dado por el usuario>` (nunca automatico, siempre decision humana explicita) y excluye ese documento de la tanda — el fingerprint queda actualizado y el `status: verified` se preserva. Si el usuario duda o dice que puede ser semantico, sigue el camino normal de abajo.
   - Documentos en `needs-semantic-review` (los que no calificaron para la alternativa de arriba, o que ya no eran `verified` antes) → estos SI necesitan el agente `bossdream-document-auditor` (paso 4).
   - Documentos ya `verified` (fingerprint sin cambios desde la ultima corrida) → se dejan como estan, no se re-evaluan.

4. **Invoca `bossdream-document-auditor` en tandas batcheadas**, nunca un dispatch por documento — cada dispatch paga el contexto/instrucciones completas del agente, asi que agrupar documentos dentro del mismo mensaje es lo que realmente ahorra tokens (a diferencia de paralelizar dispatches, que solo ahorra tiempo de reloj):
   - Arma tandas de `validation-rules.json → batchSize` documentos de `needs-semantic-review`. Si esa clave no existe en `validation-rules.json`, usa 10-15 documentos por tanda como default.
   - Para cada documento de la tanda, incluye en el mismo mensaje: el documento en cuestion + los documentos con los que podria contradecirse (nunca el proyecto completo — economia de tokens): `requirements.md` → ninguno adicional (las preguntas semanticas comparan Reglas de negocio vs Criterios de aceptacion dentro del mismo documento); `tests/test-approach.md` → `requirements.md`; `TC-XXX.md` → la US/AC que dice cubrir (de `requirements.md`).
   - Un solo despacho de `bossdream-document-auditor` por tanda, con los N documentos de esa tanda en el mismo mensaje. Si hay mas documentos que el tamano de tanda, despacha una tanda tras otra (no todas en paralelo — el ahorro esta en el batching por documento, no en simultanear tandas).
   - `bossdream-document-auditor` devuelve un bloque `VEREDICTOS:` con una entrada por documento, identificada por su nombre exacto (ver `agents/bossdream-document-auditor.md`). Recoge cada entrada y acumulala en un objeto `{ "<docKey>": { "verdict": "...", "reason": "..." } }` conforme llegan las tandas, y al final escribelo a un archivo temporal (ej. `.bossdream-project/.validation-semantic-verdicts.json`). Verifica que el `documento` de cada entrada devuelta coincida con uno de los que le pasaste en esa tanda antes de aplicarla — si `bossdream-document-auditor` devuelve un nombre que no reconoces o se salta un documento de la tanda, tratalo como hallazgo bloqueante para ese documento en vez de descartarlo en silencio.

5. **Segunda pasada**: corre `scripts/validation-check.ps1 -ProjectSlug <slug> -SemanticVerdictsPath <archivo del paso 4>`. Esto aplica los veredictos, marca `verified` o `blocked` segun corresponda, y **recalcula `overallStatus`** — solo `validation-check.ps1` puede escribir `"ready"`, nunca tu directamente.

6. **Borra el archivo temporal** de veredictos (no es estado persistente, es solo el canal para pasarle al script algo que un `.ps1` no puede generar por si mismo).

7. **Presenta el resultado segun el umbral** (`validation-rules.json → ambiguityQuestionThreshold`, default 3): cuenta el total de hallazgos bloqueantes (estructura + vocabulario duro + trazabilidad + semantica) tras la segunda pasada.
   - **≤ umbral** → presenta una sola tanda batcheada de preguntas/correcciones concretas al usuario (una pregunta por hallazgo, no un ensayo).
   - **> umbral** → lista TODOS los hallazgos de una vez, marca explicitamente que el/los documento(s) quedan invalidos, y no hagas preguntas una por una — el usuario corrige en bloque y vuelve a correr `/bossdream-validate`.
   - Si algun documento cruza `stuckThreshold` (mismo intentosBloqueado/ultimoCheckBloqueado que ya vienen en `validation.json`), suma una mención sugiriendo invocar la skill `validation-exemption-advisor` para ese documento.

8. **Si `overallStatus == "ready"`**: dilo claramente — el usuario ya puede correr `/bossdream-plan`/`/bossdream-implement` sobre este proyecto sin que `validation-lock.ps1` los bloquee.

## Reglas

- Nunca invoques `bossdream-document-auditor` sobre un documento que ya fallo deterministicamente — es fail-fast, no fail-completo.
- Nunca escribas `overallStatus: "ready"` tu mismo ni le pidas a `bossdream-document-auditor` que lo escriba — siempre pasa por `validation-check.ps1`.
- Repetible: el usuario puede correr `/bossdream-validate` tantas veces como corrija documentos; el fingerprint por documento evita re-evaluar lo que no cambio.
