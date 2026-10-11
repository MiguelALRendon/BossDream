---
name: skill-exploration
description: Auditoria completa y puntual del catalogo de skills del proyecto — mapea todo el repo, corre tech-debt a nivel de TODO el proyecto (no acotado a un flujo), y por cada duplicacion real confirmada disena con el usuario (brainstorming) la skill nueva o la actualizacion de una existente. TRIGGER — invocada por /bossdream-skill-exploration, nunca automatica.
---

# skill-exploration — auditoria del catalogo completo de skills

## Proceso

1. **Mapear el repo completo**: reusa `repo-map`/`codebase-memory` tal cual (`skills/repo-map/SKILL.md` — "capa de traduccion MCP → repo-map.json"), sin reimplementar nada de indexacion. Corre su secuencia de llamadas MCP (`search_graph`, `trace_path`, `index_status`) sobre todo el repo indexado, no un simbolo puntual, para tener modulos/simbolos/consumidores reales antes de juzgar que esta duplicado.

2. **Correr `tech-debt` a nivel de TODO el proyecto**: a diferencia del toque no-obligatorio de `/bossdream-plan` Paso 3.1 (acotado a los flujos que un plan puntual toca), aqui el alcance es el proyecto completo. Reusa la categoria "Duplicacion (codigo repetido que deberia consolidarse)" documentada en `skills/tech-debt/SKILL.md:14`, sin reimplementar deteccion propia. Para un scope de este tamano, `tech-debt` ya indica delegar la lectura a un subagente (Explore) y traer solo conclusiones (`skills/tech-debt/SKILL.md:11`).

3. **Por cada hallazgo de duplicacion real que `tech-debt` confirme** (nunca por sospecha propia): aplica el mecanismo socratico completo de `brainstorming` (`skills/brainstorming/SKILL.md`), reusando sus pasos 1-2-3-5-7:
   - Paso 1 — explorar contexto del area duplicada.
   - Paso 2 — preguntas socraticas de una en una (proposito de la skill candidata, restricciones, criterio de exito).
   - Paso 3 — reto de sobriedad (Simplicity Ladder): ¿de verdad hace falta una skill nueva o ya existe algo que la resuelve?
   - Paso 5 — presentar el diseno de la skill por secciones, aprobacion tras cada seccion, no un OK global.
   - Paso 7 — self-review (placeholders, contradicciones, ambiguedad, scope) antes de cerrar.
   - Paso 6 **adaptado**: en vez de escribir `plans/<feature>/design.md`, escribe o actualiza `skills/<nombre>/SKILL.md`.
   - Paso 8 **descartado**: no aplica, una skill no es una feature con su propio plan de increments.
   - Una skill candidata a la vez, nunca en lote sin revision individual — espera aprobacion explicita del usuario antes de escribir cada `SKILL.md`.

## Reglas

- Nunca crea ni actualiza una skill sin que `tech-debt` haya confirmado duplicacion real primero — la sospecha del mapeo (paso 1) no basta por si sola.
- Nunca escribe un `SKILL.md` sin aprobacion explicita del usuario, skill por skill.
- Puede tanto CREAR una skill nueva como ACTUALIZAR una existente, si el analisis revela que una skill ya existente quedo desactualizada respecto al patron real del codigo.
- No reimplementa `repo-map`, `tech-debt` ni `brainstorming` — los invoca y cita su seccion/proceso concreto.
