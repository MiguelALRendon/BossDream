---
name: epic-planner
description: Agrupa las capacidades detectadas en el contexto de entrada de un proyecto en candidatos de Epic (solo Complejo) y Feature (Medio+Complejo), presenta la propuesta al usuario en una sola tanda, y escribe el resultado confirmado en requirements.md + traceability.json. Nunca inventa una agrupacion sin mostrarla primero. TRIGGER — la invoca /bossdream-project al crear un proyecto, o /bossdream-update-docs cuando aparece alcance nuevo que no encaja en la jerarquia ya definida.
arguments:
  - name: contexto
    description: "el contexto/documentos de entrada del proyecto, mas la clasificacion S/M/C ya decidida"
---

# epic-planner — jerarquia Epic/Feature/US propuesta y confirmada

Las Epics y Features se proponen, nunca se declaran a mano ni se inventan en silencio.

## Que nivel aplica (depende de la clasificacion S/M/C ya decidida antes de invocar esta skill)

- **Simple** → no se propone nada. El proyecto entero es una sola unidad de trabajo; `requirements.md` va directo a User Story.
- **Medio** → se proponen Features (agrupacion de US relacionadas). No hay nivel Epic.
- **Complejo** → se proponen Epics (agrupan Features) y Features (agrupan US) dentro de cada Epic.

## Proceso

1. **Detectar capacidades**: lee el contexto/documentos de entrada y extrae las capacidades/funcionalidades distintas que menciona (sin inventar ninguna que no este ahi — mismo invariante de `docs-rewrite`: solo se escribe lo que ancla a VERIFIED en el contexto o USER-ASSERTED por el usuario).
2. **Agrupar en candidatos**: si la clasificacion es Complejo, agrupa las capacidades grandes en candidatos de Epic; dentro de cada una, agrupa las capacidades relacionadas en candidatos de Feature. Si es Medio, agrupa directo en candidatos de Feature (sin Epic).
3. **Presentar la propuesta en una sola tanda**: lista los candidatos (Epic → Features, o solo Features) con una frase de que representa cada uno, y pide confirmacion/ajuste al usuario. Nunca continua sin esta confirmacion.
4. **Ajustar segun feedback**: si el usuario fusiona, separa, renombra o descarta candidatos, aplica el ajuste y confirma el resultado final antes de escribir.
5. **Escribir el resultado confirmado**:
   - En `requirements.md`: instanciar los bloques `Epic`/`Feature` (segun clasificacion) con los nombres confirmados, dejando los IDs `EPIC-XXX`/`FEAT-XXX` secuenciales.
   - En `.bossdream-project/traceability.json`: agregar la capa `epics`/`features` correspondiente (esqueleto vacio de `stories`, se llena cuando se agreguen las US).

## Reglas

- **Nunca inventa una agrupacion sin mostrarla primero** — mismo principio que `docs-rewrite`.
- No propone nada si la clasificacion es Simple — invocar esta skill sobre un proyecto Simple es un error de quien la invoca (`/bossdream-project`/`/bossdream-update-docs`), no algo que esta skill deba resolver silenciosamente.
- Reusable desde dos comandos (`/bossdream-project` en creacion inicial, `/bossdream-update-docs` en ampliacion posterior) — no vive dentro de la logica de ninguno de los dos.
