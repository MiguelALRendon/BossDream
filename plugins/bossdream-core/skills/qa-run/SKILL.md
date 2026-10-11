---
name: qa-run
description: Ejecuta las pruebas de los casos obligatorios del Test Inventory en uno de 3 modos (Optimo/Agresivo/Costoso), tomado de `--modo` o, si falta, de `bossdream.json > qa.mode` (default costoso). TRIGGER -- el usuario pide correr/generar las pruebas de un modulo ya inventariado, o pide literalmente "qa-run"/"corre las pruebas del QA".
disable-model-invocation: true
arguments:
  - name: modo
    description: "opcional -- uno de optimo | agresivo | costoso. Sin este argumento se usa `bossdream.json > qa.mode`; si tampoco existe, costoso."
---

# qa-run -- Agente QA con 3 modos

Orquesta `test-gen` (ya existe, `skills/test-gen/SKILL.md`) y el agente `bossdream-coder` (`agents/bossdream-coder.md`) sobre los casos obligatorios del Test Inventory (`agents/bossdream-qa-gatekeeper.md`) -- no reimplementa la logica adversarial de `test-gen`.

## Paso 0 -- seleccion de modo

Orden de resolucion: `--modo` explicito, luego `bossdream.json > qa.mode`, luego `costoso`. No se muestra menu: el modo se cambia con `/bossdream-qa-mode` o con `--modo`. Registra en el reporte el modo usado y de donde salio.

```
1. Optimo    -- ejecuta los casos obligatorios uno por uno, desglosados por angulo, apoyandose en test-gen.
2. Agresivo  -- mismo trabajo que Optimo, pero un agente bossdream-coder por caso, en paralelo.
3. Costoso   -- no ahorra tokens: ejercita TODOS los casos obligatorios, con navegador cuando hay UI y consulta de solo lectura cuando hay datos, guarda hallazgos en .md y relee todo al final.
```

## Paso 1 -- casos obligatorios (comun a los 3 modos)

1. Lee `.bossdream-project/test-inventory.json`. Si no existe, para y reportalo -- sin inventario no hay casos que ejecutar (mismo criterio que `bossdream-qa-planner`: la ausencia no es excusa para inventar casos).
2. Corre `pwsh -File scripts/test-inventory-check.ps1 -InventoryPath <ruta>`. Los "casos de prueba obligatorios" son las entradas que el validador reporta sin test: cada `Missing validation coverage: <regla>` / `Missing flow transition: <de>-><a>` de su salida, mas cada entrada de `happy_paths[]`/`negative_paths[]`/`boundaries[]` del inventario sin un `tests[].cubre` exacto ya correspondiente.
3. A cada caso asignale un `angulo` segun su origen: `rules[]` -> `"regla"`; `transiciones_validas[]` -> `"happy path"` (o `"borde"` si la transicion nace de `boundaries[]`); `transiciones_invalidas[]`/`negative_paths[]` -> `"error"`. `caso_id` = el texto exacto del caso (misma cadena que usaria `tests[].cubre`, para trazabilidad).

Si el validador ya reporta `status: pass` (todo cubierto), no hay casos obligatorios pendientes -- reportalo y termina sin ejecutar ningun modo.

## Modo Optimo

Por cada caso, en orden, secuencial (nunca el siguiente antes de que termine el anterior):
1. Registra `timestamp_inicio`.
2. Invoca la skill `test-gen` sobre ese caso concreto -- pasale el `behavior`/regla/transicion exacta como el "que probar", no el modulo completo, para que no re-derive casos ya inventariados.
3. Registra `timestamp_fin` (>= al `timestamp_inicio` del caso anterior -- evidencia de secuencialidad).
4. Agrega `{caso_id, angulo, timestamp_inicio, timestamp_fin}` a `casos_ejecutados[]`.

Reporta `casos_ejecutados[]` completo al terminar.

## Modo Agresivo

Mismo trabajo que Optimo, pero en vez de invocar `test-gen` en el hilo actual, despliega **un agente `bossdream-coder` por caso** (Task/Agent tool, `agents/bossdream-coder.md`), todos lanzados en la misma tanda -- cada agente recibe el mismo caso concreto y la instruccion de invocar `test-gen` sobre el. Los rangos `timestamp_inicio`/`timestamp_fin` de los N agentes se solapan (evidencia de paralelismo). Recolecta `casos_ejecutados[]` de las N respuestas antes de reportar.

Si el numero de casos obligatorios supera 50, no lances todos los subagentes `bossdream-coder` en una sola tanda: chunkea en lotes de ~20 y procesa lote por lote, informando progreso entre lotes.

## Modo Costoso

1. Ejecuta TODOS los casos obligatorios, uno por uno (mismo mecanismo que Optimo), al nivel de un desarrollador que comprueba su trabajo: flujo feliz y validaciones rutinarias. Lo adversarial profundo es del QA Increment, no de este modo.
2. Ademas, por cada caso:
   - Si el proyecto tiene UI (`bossdream.json > style.enabled` o el plan toco markup/estilos), ejercitalo con Playwright (`mcp__plugin_bossdream-core_playwright`) y adjunta captura o snapshot. Sin UI, documenta por que en el `.md`; no bloquea.
   - Si el caso persiste datos y hay `db_dsn` configurado, confirma con `dbhub` (solo lectura) que lo escrito coincide. Sin `dbhub` conectado, anotalo como no verificado.
   - Guarda los hallazgos (que caso, que se probo a mano, que encontro) en `.bossdream-project/qa-costly-findings.md`.
3. Al terminar todos los casos, **relee `.bossdream-project/qa-costly-findings.md` completo** antes de reportar -- solo entonces el output final lleva `relectura_completada: true`.

## Reporte

- Optimo/Agresivo: `casos_ejecutados[]`.
- Costoso: ruta de `.bossdream-project/qa-costly-findings.md` + `relectura_completada: true`.

## Reglas

- El modo sale de `--modo` o de `bossdream.json > qa.mode`; nunca se asume otro en silencio.
- Nunca inventes casos que no esten en el Test Inventory -- si el inventario no existe o ya esta `pass`, no hay casos que ejecutar.
- No dupliques la logica adversarial de `test-gen` -- este skill orquesta, no genera pruebas por su cuenta.
