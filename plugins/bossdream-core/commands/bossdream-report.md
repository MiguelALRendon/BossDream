---
name: bossdream-report
description: Genera overview.md/understanding.md del proyecto activo bajo demanda, en docs/reports/<slug>/ — fuera del alcance de validation-check.ps1. Reportes humanos legibles (que se entendio y que se va a construir), reusando las plantillas de templates/_PROJECT_TEMPLATE/ a partir de requirements.md/traceability.json/tests/test-approach.md. TRIGGER — el usuario quiere un resumen humano del proyecto activo, sin que eso agregue documentos al gate de Document Validation.
disable-model-invocation: true
---

# /bossdream-report — reporte humano bajo demanda

Genera lo que `/bossdream-project` ya NO genera automaticamente: `overview.md`/`understanding.md`, en lenguaje de negocio, para que un humano los lea. No son artefactos de gobernanza — nunca pasan por `validation-check.ps1`, nunca bloquean nada.

## Pasos

1. **Localiza el proyecto activo** (`.claude/.active-project`). Si no existe o esta vacio: avisa que no hay proyecto activo, sugiere `/bossdream-set-active-project`, y PARA — no generes nada (mismo patron que `bossdream-testcase.md`).
2. **Ignora cualquier `understanding.md` legado** que pueda existir dentro de `bossdream_projects/<slug>/` (de un proyecto creado antes de este cambio) — nunca lo leas, nunca lo migres. Este comando siempre genera fresco desde la fuente real actual.
3. **Lee la fuente real**: `bossdream_projects/<slug>/requirements.md` (incluida su seccion "Reglas de negocio relevantes"), `.bossdream-project/traceability.json`, `tests/test-approach.md`.
4. **Invoca `docs-rewrite`** (mismo patron que `bossdream-project.md` paso 5) usando esa fuente para redactar `overview.md`/`understanding.md`, con las plantillas de `templates/_PROJECT_TEMPLATE/{overview.md,understanding.md}` como esqueleto. Mismos invariantes: nunca inventa (VERIFIED/USER-ASSERTED/CONFLICT), pregunta ante ambiguedad en una sola tanda.
5. **Ajusta los links relativos** de `overview.md` seccion "Documentos de esta iniciativa": en la plantilla apuntan a vecinos (`./understanding.md` etc.); en el reporte generado deben apuntar a las rutas reales — `understanding.md` es vecino (mismo `docs/reports/<slug>/`), pero `requirements.md`/`tests/test-approach.md`/`roadmap.md` viven en `bossdream_projects/<slug>/`, asi que su link relativo es `../../bossdream_projects/<slug>/<archivo>` (desde `docs/reports/<slug>/`).
6. **Escribe el resultado** en `docs/reports/<slug>/overview.md` y `docs/reports/<slug>/understanding.md` — nunca en `bossdream_projects/<slug>/`.
7. **Reporta**: que se genero, en que ruta, y que no afecta el `validation.json` del proyecto.

## Reglas

- Nunca escribe dentro de `bossdream_projects/<slug>/` — ese directorio es exclusivo de los documentos gateados por Document Validation (`requirements.md`, `tests/test-approach.md`).
- Nunca lee ni depende de un `understanding.md` legado — siempre genera fresco desde la fuente real actual.
- Repetible: correrlo de nuevo sobrescribe el reporte anterior con el estado actual del proyecto, sin pedir confirmacion (es un reporte, no un artefacto de negocio versionado con aprobacion).
- No modifica `requirements.md`, `traceability.json`, `validation.json` ni ningun archivo dentro de `bossdream_projects/<slug>/` — es de solo lectura sobre esa carpeta.
