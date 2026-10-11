---
name: validation-exemption-advisor
description: Investiga un documento atascado en el gate de Document Validation, distingue si el documento tiene un defecto real (recomienda corregirlo) de si el criterio genuinamente no aplica (propone una exencion concreta), y solo escribe en validation.json tras autorizacion explicita del usuario sobre el texto exacto. TRIGGER — invocada por nombre, o aceptada explicitamente tras la sugerencia de validation-lock.ps1/validation-run al cruzar stuckThreshold.
arguments:
  - name: documento
    description: "docKey relativo del documento atascado (ej. tests/cases/TC-77.md), senalado por el usuario o por la sugerencia de validation-lock.ps1/validation-run"
---

# validation-exemption-advisor — asesora de exenciones de Document Validation

Nunca escribe una exencion sin haber investigado la causa real primero, y nunca escribe sin un paso intermedio de autorizacion explicita del usuario.

## Proceso

1. **Requiere proyecto activo y documento senalado**: lee `.claude/.active-project`. El documento (`docKey`) viene del usuario directamente, o porque `validation-lock.ps1`/la skill `validation-run` lo sugirieron al cruzar `stuckThreshold` y el usuario acepto esa sugerencia. Si no hay proyecto activo, o no hay ningun documento senalado por ninguna de las dos vias, dilo y PARA — no adivines cual documento investigar.

2. **Corre `scripts/validation-exemption-check.ps1 -ProjectSlug <slug> -File <docKey>`** para obtener el estado real: checks bloqueados (id + findings), `intentosBloqueado`, `ultimoCheckBloqueado`, y las exenciones que ya existan para ese archivo. Si devuelve `status: 'not-found'`, dilo y PARA — no hay nada que investigar.

3. **Investiga la causa real**: lee el documento completo. Para cada check bloqueado, compara contra `validation-rules.json > documentTypes.<tipo>.semanticQuestions`/`requiredSections`/`requiredFields` del tipo de ese documento, y usa `scripts/validation-check.ps1` para saber exactamente que exige el codigo bloqueado (incluida la trampa del rango sin sub-numero en `TRACE`, aunque `TRACE` no es eximible por este mecanismo — ver Reglas).

4. **Si el documento tiene un defecto real** (falta contenido, es ambiguo, mezcla criterios, etc.): NO propone ninguna exencion. Recomienda la correccion concreta — que le falta, donde exactamente — y PARA ahi. Nunca ofrece una exencion como atajo para evitar corregir algo que si esta mal.

5. **Si el criterio no aplica a este caso concreto** (ej. un criterio que asume algo que este documento genuinamente no tiene): redacta la entrada de exencion propuesta completa — `file` (el `docKey`), `codes` (uno o mas, en MAYUSCULA), y un `motivo` ESPECIFICO que cite el contenido real del documento — nunca un motivo generico tipo "no aplica".

6. **Presenta esa entrada completa al usuario tal cual se escribiria** (el JSON exacto que iria a `exemptions[]`) y pide autorizacion EXPLICITA sobre ese texto exacto. Nunca asume un "si" implicito, nunca continua sin una respuesta clara del usuario.

7. **Solo tras el si explicito del paso 6**: edita `validation.json`, agregando la entrada a `exemptions[]` con `quien` (default `$env:USERNAME`, o quien corresponda) y `cuando` en ISO-8601 UTC (`(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')`) — mismo formato que `emergency-override.ps1`. Nunca modifica ni borra entradas existentes de otros documentos; solo agrega la nueva al final del array.

8. **Reporta el resultado**: confirma que la exencion quedo escrita (o que la correccion recomendada del paso 4 sigue pendiente), y que la proxima corrida de `validation-check.ps1` la respetara marcando el check como `EXEMPT`.

## Reglas

- Nunca se auto-invoca silenciosamente a mitad de otra tarea — solo corre cuando el usuario la invoca por nombre, o acepta explicitamente la sugerencia de `validation-lock.ps1`/`validation-run`.
- Nunca escribe en `validation.json` fuera del paso 7, y el paso 7 nunca ocurre sin haber completado el paso 6 con una respuesta explicita del usuario.
- `TRACE` (chequeo de proyecto, IDs huerfanos/fantasma) queda fuera de este mecanismo — no tiene un `file` natural, y un ID huerfano/fantasma es casi siempre un defecto de datos real, no un caso de "el criterio no aplica". Si el check bloqueado es `TRACE`, esta skill no aplica — la correccion es en `traceability.json`/la documentacion, no una exencion.
- Una exencion es permanente hasta que alguien la quite a mano — no se "consume" como `/bossdream-override`. Por eso el `motivo` especifico y la autorizacion explicita del paso 6 no son opcionales.
