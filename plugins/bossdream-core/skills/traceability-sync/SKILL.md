---
name: traceability-sync
description: Reconstruye .bossdream-project/traceability.json del proyecto activo desde los Markdown reales (requirements.md + tests/cases/*.md) cuando se sospecha que se desincronizo. El JSON es un cache derivado, nunca la fuente de verdad. TRIGGER — el usuario lo pide a demanda, o /bossdream-update-docs la invoca internamente tras un edit manual.
arguments:
  - name: proyecto
    description: "slug del proyecto activo (normalmente ya viene de .claude/.active-project)"
---

# traceability-sync — el grafo se regenera, nunca se edita a mano

## Proceso

1. Localiza el proyecto activo (`.claude/.active-project`).
2. Corre `scripts/traceability-build.ps1 -ProjectSlug <slug>` — parsea `requirements.md` (Epic/Feature/US/AC segun la jerarquia que aplique por clasificacion) y `tests/cases/*.md` (enlaza cada TC a la US/AC que declara cubrir), y **reescribe `traceability.json` completo desde cero**.
3. Reporta un resumen breve de lo que quedo registrado (cuantos Epics/Features/US/AC/TC), y si algo esperado no aparecio (ej. un TC que menciona una US que no existe en `requirements.md` — en ese caso el TC simplemente no se enlaza, y `validation-trace-check.ps1` lo marcara huerfano en la siguiente corrida de `/bossdream-validate`).

## Reglas

- **`traceability.json` nunca se edita a mano.** Si algo esta mal, se corrige en el Markdown y se vuelve a correr esta skill — el JSON siempre se puede regenerar.
- No decide nada por su cuenta (a diferencia de `epic-planner`): es puramente mecanica, no propone ni pregunta, solo re-sincroniza IDs que ya estan escritos en los documentos.
- No toca `validation.json` — eso es responsabilidad de `mark-project-dirty.ps1` (hook) o de quien invoque esta skill (ej. `/bossdream-update-docs`).
