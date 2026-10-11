---
name: plan-new
description: Crea la carpeta plans/<feature>/ con spec.md (QUE + POR QUE), plan.md (COMO), tasks.md (tareas) y un .feature Gherkin, a partir de la plantilla. Marca la feature como activa para el Gate de tareas del Completion Criteria. TRIGGER — inicio de una feature nueva, o cuando el Gate 1 readiness pide una spec antes de implementar.
disable-model-invocation: true
arguments:
  - name: feature
    description: "slug de la feature en kebab-case"
---

# plan-new — nueva especificacion

Crea `plans/<feature>/` copiando `plans/_TEMPLATE/`:

- `spec.md` — QUE se quiere y POR QUE (frontera dura, no el como). Criterios de aceptacion.
- `plan.md` — COMO: arquitectura, stack, decisiones. Referencia a spec.md.
- `tasks.md` — tareas numeradas `- [ ]`, derivadas de plan.md.
- `<feature>.feature` — Gherkin: escenarios = doc viva + base de la prueba de aceptacion. **Se generan con la skill `gherkin-gen` a partir de los criterios de aceptacion del `spec.md`** (adversarial primero, UN `@happy`, `@cubre` en cada escenario); no se deja como plantilla vacia. Si un criterio es ambiguo o no define todo el camino, `gherkin-gen` PREGUNTA en vez de inventar.

Tras crear, escribe el slug en `.claude/.active-plan` para que el Completion Criteria verifique las tareas de esta feature.

## Reglas

- Precedido por `brainstorming`: si hay `plans/<feature>/design.md` aprobado, la spec deriva de el; si no, considera correr brainstorming antes.
- La frontera QUE/COMO/TAREAS no se mezcla (spec no lleva codigo; plan no repite el que).
- spec.md debe existir antes de implementar (Gate 1 readiness). El plan.md pasa su autorevision (cobertura, sin placeholders, conflict scan) antes de codear.
- Los escenarios .feature son la fuente de verdad del comportamiento; el pipeline los ejecuta.
