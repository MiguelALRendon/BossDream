---
name: test-checks
description: Corre el Test Checks (cadena fija de 5 etapas que demuestra que una implementacion esta realmente probada, no solo "tests en verde"). TRIGGER — el usuario pide validar que algo implementado esta correctamente probado antes de cerrarlo.
disable-model-invocation: true
arguments:
  - name: run
    description: "sin valor — corre siempre las 5 etapas en orden fijo, no hay --gate selectivo"
---

# test-checks — Test Checks

Cadena fija de 5 etapas que un cambio implementado debe atravesar antes de declararse "probado": `code_correctness → contract_correctness → flow_correctness → regression_safety → quality_approval`.

A diferencia de Plan Checks y Execution Checks, `/test-checks` **no tiene `--gate`/`--check` selectivo**: siempre corre las 5 etapas, siempre en ese orden.

Este skill produce sus propios artefactos, separados de Execution Checks: Execution Checks (`/execution-checks --check correctness-chain`) invoca este mismo script para evaluar la cadena contra un `--diff` real, pero `/test-checks --run` es el motor propio de esta cadena — no una copia.

Correr a mano:

```
pwsh -File scripts/test-checks.ps1 -ProjectDir <ruta al proyecto, default $env:CLAUDE_PROJECT_DIR>
```

## Las 5 etapas

- `code_correctness`: reusa `pipeline.ps1 -Tier local` (el pipeline de codigo ya existente, invocado como subproceso, nunca reimplementado) como una sola unidad. `status: "passed"` si su exit code es 0; si no, `"failed"` con `severidad`/`condicion_de_bloqueo` extraidos del texto `PIPELINE FAIL en etapa '<id>': ...` y `escape_hatch: null` (`pipeline.ps1` no tiene mecanismo de escape hatch hoy).
- `contract_correctness`: check agnostico de stack — busca `**/*.openapi.yaml` y `**/*.schema.json` en el repo e intenta parsear cada uno. Sin contratos → `"passed"`. Alguno no parsea → `"failed"` con el archivo y el error concretos. Deliberadamente modesto: valida sintaxis, no hace diff semantico contra la implementacion real (eso requeriria tooling especifico de stack, fuera de alcance de este motor).
- `flow_correctness`: **stub estructural** `{status: "pending", nota: "..."}` — nunca `"passed"` sin verificacion real.
- `regression_safety`: gateado por `bossdream.json > testing.enabled`/`testing.project` (mismo patron que `pipeline.ps1`). `testing.enabled=false` → `"skipped"`. `testing.enabled=true` sin herramienta de mutation testing disponible para el stack del proyecto de pruebas → `"skipped"` con `nota` explicando por que (honestidad, no se finge `"passed"`). Con herramienta disponible → `"passed"`/`"failed"` segun su resultado.
- `quality_approval`: **stub estructural** `{status: "pending", ...}` por logica de negocio propia (requiere QA Manager/Flow-Based Testing) — PERO si `code_correctness`, `contract_correctness` o `regression_safety` fallaron, se sobreescribe a `{status: "failed", severidad: "hard", condicion_de_bloqueo: "una o mas etapas previas fallaron", escape_hatch: null}`. El bloqueo por etapas previas es determinista y no depende de QA Manager.

## Reporte

Objeto JSON con las 5 claves en el orden fijo de arriba, cada una con `status` y, si `"failed"`, `severidad`/`condicion_de_bloqueo`/`escape_hatch`. Exit code 0 salvo que `quality_approval.status` sea `"failed"` (exit 1).
