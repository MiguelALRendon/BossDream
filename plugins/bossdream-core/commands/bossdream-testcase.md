---
name: bossdream-testcase
description: Genera un nuevo caso de prueba (TC-XXX.md) para el proyecto activo, presentado al usuario para aprobar/corregir/rechazar antes de registrarlo. Cada corrida reabre validation.json a blocked. TRIGGER — el usuario quiere agregar un caso de prueba formal (Medio/Complejo) a un proyecto ya scaffoldeado.
disable-model-invocation: true
arguments:
  - name: escenario
    description: "descripcion breve del escenario a probar, en palabras del usuario"
---

# /bossdream-testcase — nuevo caso de prueba

Un TC a la vez, siempre aprobado explicitamente antes de registrarse — mismo principio que la construccion incremental de increments en `/bossdream-plan`.

## Pasos

1. **Localiza el proyecto activo** (`.claude/.active-project`) y su clasificacion. Si es **Simple**, dilo: Simple solo usa la checklist de smoke test (`tests/test-approach.md §2`), no casos de prueba formales — PARA.
2. **Identifica la US/AC** que este caso cubre — pregunta si no es evidente del `escenario` dado o del contexto reciente.
3. **Siguiente ID disponible**: revisa `tests/cases/` y usa `TC-XXX` con el siguiente numero secuencial.
4. **Copia la plantilla** `tests/_templates/test-case.md` a `tests/cases/TC-XXX.md` y **redacta el contenido** (Escenario, Precondiciones, Datos de prueba, Pasos, Resultado esperado — sin ambiguedad, un solo AC por caso, nunca varios criterios mezclados). `Resultado obtenido`/`Estado`/`Evidencia` quedan pendientes de la ejecucion real.
5. **Presenta el caso completo al usuario** para aprobar, corregir o rechazar — nunca lo des por registrado sin esta confirmacion explicita.
6. **Si se aprueba**: invoca `scripts/testcase-register.ps1 -ProjectSlug <slug> -TcId TC-XXX -UsId US-YYY -AcIds <AC-YYY.N>` — esto registra el TC en `traceability.json`, agrega la entrada a `validation.json` (forzando `overallStatus: "blocked"`), y actualiza la tabla resumen de `tests/test-approach.md §7`.
7. **Si se rechaza o pide correccion**: ajusta y vuelve al paso 5. Nunca registres un TC no aprobado.

## Reglas

- Un TC por corrida — nunca generes varios en lote sin aprobacion individual de cada uno.
- El TC prueba **exactamente un AC** — si el escenario cubre varios criterios, son varios TC.
- Nunca marca `validation.json` como `ready` — `testcase-register.ps1` siempre lo reabre a `blocked` (decision 2b); solo `validation-check.ps1` (via `/bossdream-validate`) puede volver a cerrarlo.
- No toca codigo, no modifica los comandos/scripts core del motor del Delivery Cycle (`bossdream-plan.md`, `bossdream-implement.md`).
