---
name: bossdream-update-docs
description: Registra los cambios que el usuario hizo a mano en los documentos del proyecto activo (ediciones a documentos existentes, o alcance nuevo que aparecio y necesita integrarse a la jerarquia Epic/Feature/US). Reabre el Document Validation cuando corresponde. TRIGGER — el usuario edito documentos manualmente y quiere que el sistema se entere, o describe alcance nuevo que todavia no esta escrito en requirements.md.
arguments:
  - name: alcance_nuevo
    description: "opcional: descripcion en palabras del usuario de una capacidad/alcance nuevo que todavia no esta en requirements.md"
---

# /bossdream-update-docs — sincroniza ediciones manuales y alcance nuevo

La mayoria de las ediciones a documentos **ya registrados** las detecta solo el hook `mark-project-dirty.ps1` (marca `pending` el documento especifico, sin que el usuario tenga que recordar nada). Este comando cubre lo que ese hook **no** puede resolver por si mismo: archivos nuevos y alcance nuevo, que requieren interpretacion.

## Pasos

1. **Si se dio `alcance_nuevo`**: invoca la skill `epic-planner` (igual que en `/bossdream-project`, decision 9) para proponer donde encaja — nueva Feature, nueva US dentro de una Feature existente, o incluso un Epic nuevo si la clasificacion es Complejo. Presenta la propuesta al usuario en una sola tanda, nunca la escribas en silencio. Una vez confirmada, escribela en `requirements.md`.
2. **Siempre**: invoca la skill `traceability-sync` para reconstruir `.bossdream-project/traceability.json` desde los Markdown actuales — recoge automaticamente cualquier Epic/Feature/US/AC/TC que el usuario haya escrito a mano, sin necesidad de que este comando sepa interpretarlos uno por uno.
3. **Siempre**: invoca `scripts/validation-check.ps1 -ProjectSlug <slug>` (primera pasada, sin `-SemanticVerdictsPath`) — esto descubre automaticamente cualquier documento nuevo (ej. un `TC-XXX.md` copiado a mano sin pasar por `/bossdream-testcase`) y lo agrega a `validation.json`; si algun documento ya `verified` cambio de fingerprint, tambien lo reabre. El propio script recalcula `overallStatus`.
4. **Reporta**: que se agrego/reabrio, y el estado final de `overallStatus`.

## Reglas

- Nunca marca nada como `ready` — eso sigue siendo exclusivo de `validation-check.ps1` corrido desde `/bossdream-validate` (con la segunda pasada semantica).
- Si `alcance_nuevo` describe algo que ya esta escrito en los documentos, no lo dupliques — pregunta antes de asumir que es nuevo.
- No toca codigo, no modifica los comandos/scripts core del motor del Delivery Cycle (`bossdream-plan.md`, `bossdream-implement.md`).
