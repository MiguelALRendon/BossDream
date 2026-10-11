---
name: bossdream-validate
description: Corre el pipeline de Document Validation batcheado por check (no documento por documento) sobre el proyecto activo, con la profundidad que le toque segun su clasificacion S/M/C. Repetible hasta que todos los documentos queden verified. TRIGGER — el usuario termino de revisar/ajustar los documentos generados por /bossdream-project (especialmente tests/test-approach.md) y quiere desbloquear /bossdream-plan.
disable-model-invocation: true
---

# /bossdream-validate — pipeline de Document Validation

Comando delgado — toda la logica vive en la skill `validation-run` (mismo patron que `/pipeline` es delgado y la logica vive en la skill `pipeline`).

## Pasos

1. Invoca la skill `validation-run` sobre el proyecto activo (`.claude/.active-project`).
2. Si no hay proyecto activo, dilo y sugiere `/bossdream-project` primero — PARA.
3. Deja que `validation-run` corra las 2 pasadas (deterministica + semantica), presente hallazgos segun el umbral de ambiguedad, y actualice `validation.json`.
4. Reporta el resultado final: `overallStatus` (`ready`/`blocked`) y, si sigue `blocked`, la lista concreta de lo que falta corregir.

## Reglas

- Nunca marca nada como `ready` por su cuenta — eso lo decide `validation-check.ps1` (invocado por la skill), nunca el agente.
- Repetible sin limite: cada corrida solo re-evalua documentos cuyo fingerprint cambio desde la ultima vez.
- No toca codigo, no modifica los comandos/scripts core del motor del Delivery Cycle (`bossdream-plan.md`, `bossdream-implement.md`).
