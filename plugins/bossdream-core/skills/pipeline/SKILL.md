---
name: pipeline
description: Corre el pipeline de calidad del proyecto (etapas ordenadas por costo/feedback) o explica su configuracion. TRIGGER — el usuario pide correr los checks, validar antes de done, o preguntar por el orden/estado del pipeline. El Stop hook ya lo corre solo en tier local antes de done.
disable-model-invocation: true
arguments:
  - name: tier
    description: "local (rapido, incremental) | ci (completo) | all (incluye nightly)"
  - name: skip
    description: "salta el pipeline registrando un motivo (WIP); queda en el reporte, no silencioso"
---

# pipeline — cadena de verificaciones de calidad

"Pipeline" = la cadena de verificaciones que el codigo atraviesa antes de darse por terminado (no el guante de armadura). Es el identificador tecnico del framework.

Runner generico que lee `pipeline.json` del proyecto. El motor es agnostico; los comandos (`dotnet ...`, `npm ...`, segun el stack-pack de lenguaje instalado) son config del proyecto/stack.

## Orden (por costo/feedback, fail-fast)

| # | Etapa | Tier | Bloqueo |
|---|---|---|---|
| 1 | Build + warnings-as-errors | local+ci | duro |
| 2 | Formato | local+ci | duro |
| 3 | Comentarios prohibidos | local+ci | duro |
| 4 | Analisis estatico | local+ci | duro |
| 5 | Arquitectura | local+ci | duro (apagado hasta configurar) |
| 6 | Unit + cobertura | local+ci | duro |
| 7 | Integration | ci | duro (apagado hasta configurar) |
| 8 | BDD Gherkin | ci | duro |
| 9 | E2E | ci | duro (apagado hasta configurar) |
| 10 | Mutation (Stryker) | local+ci | duro — **obligatorio con `testing.enabled=true`**, multi-lenguaje (Stryker.NET/StrykerJS) |
| 11 | Doc drift | ci | blando |

## Ejecucion

- Local (Stop hook): etapas 1-6 + 10 (si `testing.enabled`), incremental. Feedback en segundos, sin infra.
- CI (push): 1-9 + 11, completo.
- Salida: en exito una linea `pipeline OK`; en fallo solo la etapa rota (economia de tokens).

Correr a mano: `pwsh -File scripts/pipeline.ps1 -Tier local`. Config: `pipeline.json`. Toggles por proyecto (E2E on/off, thresholds).
