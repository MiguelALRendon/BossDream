---
name: bossdream-set-active-project
description: Activa, cambia o desactiva el proyecto activo (.claude/.active-project) — puntero LOCAL por desarrollador, nunca compartido via git. Sin argumento, informa el estado actual. TRIGGER — el usuario quiere retomar un proyecto que otro dev ya documento, cambiar de proyecto para apoyar en otro, o volver al modo normal (bossdream-plan/bossdream-implement sin gobernanza de proyecto) para una tarea suelta.
disable-model-invocation: true
arguments:
  - name: accion
    description: "slug de un proyecto existente en bossdream_projects/ para activarlo, o 'clear' para desactivar. Vacio = solo informa el estado."
---

# /bossdream-set-active-project — activar, cambiar o desactivar el proyecto activo

`.claude/.active-project` es un puntero **local, por desarrollador** — nunca se comparte vía git (se fusiona a `.gitignore` por `project-scaffold.ps1`). Lo que **sí** se comparte es `bossdream_projects/<slug>/` completo (documentos + `.bossdream-project/*.json`) — cualquier dev con el repo clonado puede activarlo apuntando aquí, sin haberlo creado él mismo.

## Casos de uso

- **Otro dev ya armó el proyecto y lo documentó** (`/bossdream-project` + ediciones) y tú quieres retomarlo: `/bossdream-set-active-project <slug>`.
- **Necesitas interrumpir para apoyar en otro proyecto**: `/bossdream-set-active-project <otro-slug>` — sobreescribe el puntero, sin tocar el proyecto anterior (sigue en su `bossdream_projects/<slug>/` de siempre, listo para retomar después).
- **Necesitas planear/implementar algo suelto sin que la gobernanza de proyecto interfiera**: `/bossdream-set-active-project clear` — vuelve al modo normal; `/bossdream-plan`/`/bossdream-implement` funcionan exactamente igual que sin ningun proyecto activo.
- **No recuerdas qué tienes activo, o qué proyectos existen**: `/bossdream-set-active-project` (sin argumento) — solo informa, no cambia nada.

## Pasos

1. Invoca `scripts/set-active-project.ps1` con la acción correspondiente:
   - Con slug → `-Action activate -ProjectSlug <slug>`.
   - Con `clear` → `-Action clear`.
   - Sin argumento → `-Action status`.
2. Si `activate` falla porque el slug no existe, el script ya lista los proyectos disponibles en `bossdream_projects/` — muéstraselos al usuario tal cual, no inventes otros.
3. Reporta el resultado: proyecto activado (con su clasificación y `validation.json.overallStatus`), confirmación de limpieza, o el status informativo.

## Reglas

- Nunca crea un proyecto nuevo — si el slug no existe, es un error, no se ofrece crearlo (para eso está `/bossdream-project`).
- Nunca modifica `validation.json`/`traceability.json`/ningún documento del proyecto — solo cambia el puntero local.
- No toca código, no modifica los comandos/scripts core del motor del Delivery Cycle (`bossdream-plan.md`, `bossdream-implement.md`).
