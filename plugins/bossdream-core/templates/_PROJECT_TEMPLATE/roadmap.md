# Plan — Indice/Rollup — [Nombre del proyecto]

> Generado por `/bossdream-plan` (extension via el hook `plan-context-inject.ps1` — `commands/bossdream-plan.md` no se modifica, decision 10). Este archivo es un **indice**, NO un `plan.md` ejecutable — `/bossdream-implement` no lo lee. Cada Feature conserva su propio `plans/<feature>/plan.md` de siempre (decision 8).

## Epics / Features

| Epic | Feature | Estado | plans/ |
|---|---|---|---|
| [EPIC-XXX o "—" si Medio/Simple] | [FEAT-XXX o "—" si Simple] | pendiente / planeada / en progreso / hecha | `plans/<feature>/` |

## QA Increment

Se agrega siempre como la ultima Feature del rollup, nunca se omite.

| Feature | Estado | plans/ |
|---|---|---|
| QA Increment | pendiente | `plans/<slug>-qa-increment/` |

## Progreso de planeacion multi-sesion

Ver `.bossdream-project/plan-progress.json` para el detalle exacto de que Epic/Feature ya se planeo y que queda pendiente — este archivo no duplica ese detalle, solo referencia el estado agregado.
