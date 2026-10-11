---
name: qa-increment
description: Ejecuta el QA Increment/Testing como paso nombrado y separado del flujo de implementacion -- corre el Test Checks completo, despacha el veredicto real del QA Manager y bloquea el cierre del increment si el veredicto es REJECTED. TRIGGER -- el usuario pide cerrar una tarea/feature y llega al ultimo increment del plan, o pide literalmente "corre el QA Increment"/"qa-increment".
disable-model-invocation: true
arguments:
  - name: run
    description: "sin valor -- corre el QA Increment/Testing completo sobre el proyecto activo"
---

# qa-increment -- QA Increment/Testing

Paso NOMBRADO y SEPARADO del flujo -- no un chequeo embebido silenciosamente dentro del increment de "implementar". Se agrega siempre como la **ultima entrada** del rollup de increments de la tarea/feature (`plan.md`), con el nombre literal exacto `"QA Increment/Testing"` -- mismo lugar y mismo mecanismo que hoy usa `flow-test-gen` para agregar su propio "QA Increment" como ultima Feature de `roadmap.md` (`scripts/plan-context-inject.ps1`), pero a nivel de tarea/feature en vez de a nivel de proyecto. Orquesta, en este orden, agente `bossdream-qa-planner` (modo `--run`) -> `/qa-run` -> agente `bossdream-qa-auditor` (modo `--run`).

## Cuando corre

Cuando el loop de increments de la tarea/feature llega al ultimo increment del `plan.md` (el nombrado `"QA Increment/Testing"`). Necesita `.bossdream-project/test-inventory.json`; si falta, el Paso 0 lo genera con `agents/bossdream-qa-gatekeeper.md`. Nunca se acepta por ausencia de inventario.

**Insumo informativo opcional -- `smoker-log.json`:** si `.bossdream-project/smoker-log.json` existe (casos adversariales/limite ya ejecutados por `agents/bossdream-smoker.md` durante los increments de implementacion, Fase 6.5), se ofrece como insumo adicional a `bossdream-qa-gatekeeper`/`bossdream-qa-planner` -- casos reales ya probados en desarrollo, para no duplicar trabajo. Nunca reemplaza ni exime la derivacion desde codigo real que `agents/bossdream-qa-gatekeeper.md` sigue exigiendo; su ausencia no bloquea nada de lo anterior.

## Paso 0 -- Test Inventory (solo si falta o esta desactualizado)

Si `.bossdream-project/test-inventory.json` no existe, o es anterior al ultimo cambio de los archivos que el plan toco:

1. Despacha el agente `bossdream-qa-gatekeeper` pasandole el `plan.md`, los archivos de codigo tocados y, si existe, `.bossdream-project/smoker-log.json`.
2. Guarda su respuesta tal cual en `.bossdream-project/test-inventory.json`.
3. Corre `pwsh -File scripts/test-inventory-check.ps1 -InventoryPath <ruta>`. Si devuelve `status: blocked` por forma invalida (no por casos sin prueba), el QA Increment queda bloqueado con esa razon literal: no se continua ni se inventa un inventario a mano.

Si el inventario ya existe y esta al dia, se usa tal cual.

## Paso 1 -- Test Checks completo (determinista)

Corre `pwsh -File scripts/test-checks.ps1 -ProjectDir <ruta del proyecto>` completo (las 5 etapas: `code_correctness/contract_correctness/flow_correctness/regression_safety/quality_approval`).

- **Excepcion — huecos de cobertura:** si la UNICA etapa fallida es `flow_correctness` y su `razon[]` son solo lineas `Missing validation coverage:` / `Missing flow transition:` (el inventario es valido, faltan pruebas), no es un fallo del codigo sino el insumo del QA Increment: ve directo al Paso 3 (`qa-run`) con esas razones como casos obligatorios, y despues repite este Paso 1. Una forma invalida del inventario (`status: blocked` sin esas lineas) o cualquier otra etapa fallida SI bloquea como sigue.
- Si `quality_approval.status == "failed"` (alguna etapa previa fallo -- deterministico, no depende de juicio semantico): el QA Increment/Testing queda **BLOQUEADO de inmediato**, mismo mecanismo que `pipeline.ps1` usa hoy para bloquear un increment con checks fallidos (mensaje `PIPELINE FAIL en etapa '<id>'...`, exit no-cero). No se invoca `bossdream-qa-planner` -- no hay nada que juzgar semanticamente si lo deterministico ya fallo. Ir directo al Paso 5 (evidencia) con `bloqueado: true`.
- Si `quality_approval.status == "requires-agent"` (todo lo deterministico paso): continuar al Paso 2. Si ademas `quality_approval.flow_breaker` esta presente (`flow_correctness` traia `flows[]` no vacio, spec `armar-piezas-sueltas`), el Paso 2 despacha **tambien** `bossdream-flow-breaker` con `flows[]` del `test-inventory.json` -- su VEREDICTO es el resultado final de esa capa (nunca vuelve a pasar por `test-checks.ps1`); un `VERDICT: blocked` de `flow-breaker` se trata igual que un `QA VERDICT: REJECTED` de `bossdream-qa-planner` (continua al Paso 3 citando la razon literal del agente).

## Paso 2 -- QA Manager, primera pasada (agente `bossdream-qa-planner` (modo `--run`))

Invoca el agente `bossdream-qa-planner` real (Task/Agent tool, mismo mecanismo documentado en `skills/bossdream-qa-planner/SKILL.md`) pasandole: `.bossdream-project/test-inventory.json`, el JSON completo de Test Checks del Paso 1, y hallazgos de `agents/bossdream-qa-auditor.md` si ya existen de una corrida previa (opcional, nunca inventado).

- **`QA VERDICT: ACCEPTED`** sin razones: saltar directo al Paso 5 -- QA Increment/Testing cerrable.
- **`QA VERDICT: REJECTED`** con razones: continuar al Paso 3 (remediacion). El veredicto y sus razones se usan tal cual -- nunca se reinterpretan ni se suavizan.

## Paso 3 -- `/qa-run` (remediacion, solo si Paso 2 fue REJECTED)

Invoca `skills/qa-run/SKILL.md` sobre los casos obligatorios que las razones del veredicto citan (`Missing validation coverage: <regla>` / `Missing flow transition: <de>-><a>` / etc.) -- en el modo de `bossdream.json > qa.mode` (default `costoso`; ver `/bossdream-qa-mode`), sin duplicar la logica de `qa-run`. Objetivo: cerrar exactamente los huecos que `bossdream-qa-planner` nombro, no generar pruebas nuevas sin relacion con el veredicto.

## Paso 4 -- agente `bossdream-qa-auditor` (modo `--run`) (auditoria antes de re-verificar)

Invoca el agente `agents/bossdream-qa-auditor.md` sobre las pruebas nuevas del Paso 3 (y las existentes si aplica) -- si encuentra hallazgos criticos (`assertion_trivial`, `falso_positivo`, etc.) sobre las pruebas recien agregadas, se corrigen antes de continuar; si no hay `agents/bossdream-qa-auditor.md` disponible en el entorno de invocacion, se omite sin bloquear (mismo criterio opcional que ya documenta `skills/bossdream-qa-planner/SKILL.md`).

## Paso 5 -- QA Manager, veredicto final

Si se paso por el Paso 3/4, vuelve a correr agente `bossdream-qa-planner` (modo `--run`) (mismo mecanismo del Paso 2) sobre el estado actualizado del Test Inventory/pruebas.

- **`ACCEPTED`**: QA Increment/Testing cerrable -- se puede marcar como hecho en `plan.md`.
- **`REJECTED`** (persiste tras la remediacion): QA Increment/Testing queda **BLOQUEADO** -- nunca se marca como hecho en `plan.md`, se reportan las razones citadas tal cual, y el cierre de la tarea/feature se detiene hasta que se agregue el test faltante y se vuelva a invocar este mismo skill sobre el mismo increment.

## Paso 6 -- Evidencia propia (siempre, sea cual sea el resultado)

Escribe `.bossdream-project/qa-increment-evidence.json`, distinto de `implementation.diff`/`plan-draft.json`:

```json
{
  "ejecutado_en": "<timestamp ISO>",
  "test_pipeline_result": { "...": "JSON completo del Paso 1" },
  "qa_manager_veredicto": { "status": "ACCEPTED|REJECTED", "razones": ["Missing flow transition: ..."] },
  "remediacion_aplicada": true,
  "bloqueado": true,
  "motivo_bloqueo": "QA VERDICT: REJECTED -- Missing flow transition: Pending -> Cancelled",
  "afirmaciones": [
    { "texto": "Missing flow transition: Pending -> Cancelled", "evidencia_adjunta": null }
  ]
}
```

`bloqueado`/`motivo_bloqueo` son `false`/`null` cuando el veredicto final es `ACCEPTED`. `remediacion_aplicada` es `false` si el veredicto fue `ACCEPTED` ya en el Paso 2 (nunca se llego al Paso 3/4).

`afirmaciones[]` (spec `armar-piezas-sueltas`): una entrada por cada razon literal de `qa_manager_veredicto.razones[]` -- `{texto: <razon literal>, evidencia_adjunta: null}` salvo que la razon cite una ruta de archivo concreta, en cuyo caso esa ruta va en `evidencia_adjunta`. Si `razones[]` esta vacio (veredicto `ACCEPTED` sin razones), `afirmaciones[]` queda `[]`. Tras escribir el archivo, despachar `bossdream-evidence-auditor` sobre `afirmaciones[]` -- su VEREDICTO (`VERDICT: pass|blocked`) queda registrado junto al archivo como evidencia adicional de que las razones citadas no son solo texto sin respaldo; no vuelve a pasar por este skill ni cambia `bloqueado`/`motivo_bloqueo` (esos ya los fijo `qa_manager_veredicto`, `evidence-auditor` audita la evidencia, no re-decide el veredicto de QA).

## Reglas

- Nunca marca el QA Increment/Testing como hecho en `plan.md` si el veredicto final de `bossdream-qa-planner` es `REJECTED` -- el bloqueo es real, no informativo.
- Nunca reinterpreta ni suaviza un `REJECTED` -- las razones se citan tal cual las emite `bossdream-qa-planner`.
- Nunca corre `/qa-run` sin un veredicto `REJECTED` previo que nombre huecos concretos -- invocarlo sin huecos conocidos no genera nada que testear (mismo criterio que ya aplica `qa-run` por su cuenta: sin inventario o con `status: pass`, no hay casos que ejecutar).
- Siempre escribe `.bossdream-project/qa-increment-evidence.json`, incluso si el resultado es un bloqueo por el Test Checks en el Paso 1 (sin llegar a invocar `bossdream-qa-planner`).

## Pendiente

- Invocacion viva completa del ciclo de 5 pasos (Task/Agent tool + usuario interactivo) por el orquestador -- este entorno de implementacion no tiene esas herramientas.
- Wiring del append automatico de `"## QA Increment/Testing"` como ultima entrada de un `plan.md` generado en vivo (equivalente, a nivel de tarea/feature, al mecanismo que `plan-context-inject.ps1` ya aplica a `roadmap.md` a nivel de proyecto) -- fuera del alcance de este increment (8.1 solo pedia crear este skill y el gate de `completion.json`).
