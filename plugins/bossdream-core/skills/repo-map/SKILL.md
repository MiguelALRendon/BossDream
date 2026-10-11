---
name: repo-map
description: Genera .bossdream-project/repo-map.json bajo demanda traduciendo consultas reales al MCP codebase-memory (search_graph, trace_path, index_status) al schema de 7 campos (archivo, linea, consumidores, tests, dependencias, generado_en, stale). Es una capa fina sobre el MCP, no un indexador nuevo — codebase-memory ya cubre eso funcionalmente, lo unico que faltaba era el mapeo consulta-a-JSON. TRIGGER — cuando una skill/agente necesita "que consume X" / "que tests cubren X" y quiere resolverlo sin invocar el MCP directo ni abrir archivos (nivel 3 de la cascada de context-router).
---

# repo-map — capa de traduccion MCP → repo-map.json

## Por que existe

`codebase-memory` ya responde esas consultas con datos reales de grafo. Lo que el MCP no hace es escribir un archivo estatico `.bossdream-project/repo-map.json` con el schema exacto de 7 campos que se consulta con `jq` — es un grafo consultado en vivo, no un exportador. Este skill es esa traduccion, no un indice nuevo: por cada simbolo, ejecuta 4 llamadas MCP y arma una entrada del JSON.

## Mapeo consulta MCP → campo del schema

| Campo(s) | Llamada MCP | Como se deriva |
|---|---|---|
| `archivo`, `linea` | `search_graph(qn_pattern=".*<Simbolo>$", relationship="CALLS", fields=[qn,file,lines,in,out])` | `file` → `archivo`; `lines` (ej. `"1-10"`) → `linea` tal cual la devuelve el MCP, sin reformatear. |
| `consumidores` | `trace_path(function_name="<Simbolo>", direction="inbound", include_tests=true, depth=1)` | De la lista de callers devuelta, quedarse solo con los que tienen `test: false` → sus rutas de archivo van a `consumidores[]`. |
| `tests` | Mismo `trace_path` inbound de arriba (una sola llamada cubre ambos campos) | De la misma lista, los callers con `test: true` → sus rutas van a `tests[]`. |
| `dependencias` | `trace_path(function_name="<Simbolo>", direction="outbound", depth=1)` | Rutas de archivo de los callees devueltos → `dependencias[]`. |
| `generado_en` | `index_status(diagnostics=summary)` | Campo `indexed_at` de la respuesta, copiado literal (mismo timestamp para todas las entradas generadas en la misma corrida). |
| `stale` | Comparar `indexed_at` (paso anterior) contra `detect_changes` (git diff posterior a esa fecha) o un `index_status` nuevo | Si hay cambios de archivo con fecha posterior a `indexed_en` → `stale: true` y se agrega `stale_desde` (timestamp del cambio mas reciente detectado); si no hay cambios → `stale: false` y `stale_desde` no se incluye (el schema tiene 7 campos en reposo, 8 cuando esta stale). |

Evidencia real de que este mapeo produce datos correctos (no hipotetico): `search_graph(qn_pattern=".*Test-FieldFilled$", ...)` devolvio `archivo: scripts/pipeline-helpers.psm1`, `linea: 1-10`, `in: 13`, `out: 0`; `trace_path(function_name="Test-FieldFilled", direction="inbound", include_tests=true, depth=1)` devolvio los 13 callers reales con el flag `test` por cada uno — `Validate-ItemFields` (`test: false`, va a `consumidores`) vs. `Test-BehaviorCoverage` en `test-inventory-check.ps1` (`test: true`, va a `tests`). Corrida real del orquestador.

## Como se invoca

No es un script `.ps1` — las tools MCP (`search_graph`, `trace_path`, `index_status`, `detect_changes`) solo las tiene el agente/modelo, no PowerShell. El skill es una secuencia que el propio agente ejecuta:

1. Recibir el/los simbolo(s) a mapear (o "todo el repo indexado" si no se pasa ninguno).
2. Por cada simbolo: las 4 llamadas MCP de la tabla de arriba.
3. Armar el objeto `{ "<Simbolo>": {archivo, linea, consumidores, tests, dependencias, generado_en, stale[, stale_desde]} }` y mezclarlo con las entradas existentes en `.bossdream-project/repo-map.json` (no sobrescribir simbolos no tocados en esta corrida).
4. Escribir el archivo en UTF-8 sin BOM (mismo criterio que `context-router.log`) para que sea legible por `jq`/parsers JSON estrictos sin corromper acentos.

## Invalidacion

No hay mecanismo nuevo que construir: `codebase-memory` ya trackea `indexed_at` (`index_status`) y expone `detect_changes` para saber que archivos cambiaron desde esa fecha. El skill reusa ambos en el paso `stale` de la tabla de arriba — nunca sirve `stale: false` en silencio si hay cambios posteriores a `indexed_at` sin re-indexar.

## Reglas

- Nunca fabricar `consumidores`/`tests`/`dependencias` sin la llamada `trace_path` real — si el MCP no responde o el simbolo no existe en el grafo, la entrada no se escribe (no se inventa un array vacio como si fuera dato real).
- `linea` se copia tal cual la devuelve `search_graph` — no se recalcula por otra via.
- Reindexar (`index_repository`) antes de mapear si `index_status` reporta `stale` a nivel de repo — evita propagar datos viejos al JSON.
