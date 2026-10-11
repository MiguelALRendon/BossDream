---
name: execution-checks
description: Corre el Execution Checks (4 chequeos que demuestran que un implementation.diff real cumple lo planeado, sin fuera de alcance, y esta correctamente probado). TRIGGER — el usuario pide validar un diff/implementacion antes de cerrar la tarea.
disable-model-invocation: true
arguments:
  - name: plan
    description: "ruta a plan-draft.json aprobado"
  - name: diff
    description: "ruta a implementation.diff (unified diff formato git diff/diff -u)"
  - name: check
    description: "uno de: diff-intelligence | plan-to-code-traceability | unintended-change-detector | correctness-chain"
  - name: scope
    description: "local (default) | global"
---

# execution-checks — Execution Checks

4 chequeos sobre un `implementation.diff` real, contrastado contra el `plan-draft.json` aprobado.

Correr a mano:

```
pwsh -File scripts/execution-checks.ps1 -Plan <plan-draft.json> -Diff <implementation.diff> -Check <valor> [-Scope local|global] [-ProjectDir <ruta>]
```

## Formato del diff

`implementation.diff` es un unified diff estandar (`git diff`/`diff -u`): `--- a/<archivo>`/`+++ b/<archivo>` marcan el archivo, `@@ ... @@` marca hunks, lineas `+`/`-` (sin contar `+++`/`---`) son agregado/eliminado. Se parsea con regex/split de lineas — sin dependencia de terceros.

## Los 4 `--check`

- `diff-intelligence`: clasifica cada archivo del diff en `agregado[]` (solo lineas `+` en su bloque), `eliminado[]` (solo lineas `-`), `modificado[]` (ambas). `comportamiento_cambiado` queda `""` — describir semanticamente que comportamiento cambio exige entender el codigo, no el diff crudo; dejarlo vacio es honesto, no una heuristica inventada.
- `plan-to-code-traceability`: cruza `plan-draft.json.pasos[]` contra cada archivo del diff (busqueda de texto plano del nombre de archivo en `paso.action`/`paso.expected_output`) y produce filas `{requirement, ac, plan_step, code_change, test, qa_evidence}`. `requirement`/`ac` quedan `""` siempre — el formato de `plan-draft.json` no fija de donde saldrian, inventar el origen violaria "nunca declarar sin evidencia". Cuando hay al menos una fila, el resultado gana `traceability_watcher: {status: "requires-agent", agente: "bossdream-traceability-watcher", instruccion}` — este script no evalua eslabones rotos no sistemicos (columna vacia en una fila especifica, no en todas), eso es juicio del agente (spec `armar-piezas-sueltas`).
- `unintended-change-detector`: compara los archivos del diff contra `archivos_primarios[]`/`archivos_tocados[]` del plan → `fuera_de_alcance[]` (en el diff, no en el plan). `modificaciones_accidentales[]` y `complejidad_innecesaria[]` quedan siempre `[]` — detectarlas exige diffear linea por linea contra cada paso del plan y leer el codigo en busca de abstraccion no pedida, analisis que excede lo que este dispatcher determinista puede hacer sin heuristica arriesgada; limitacion conocida, documentada, no simulada. Cuando `fuera_de_alcance[]` queda vacio, el resultado gana `scope_enforcer: {status: "requires-agent", agente: "bossdream-scope-enforcer", instruccion}` — este script compara rutas de forma cruda (`-notcontains`), sin normalizar `\`/`/`, sin manejar renames via similarity index ni case-sensitivity; eso es lo que el agente cubre antes de poder decir "pass" con confianza.
- `correctness-chain`: invoca `scripts/test-checks.ps1 -ProjectDir <ProjectDir>` como subproceso (reuso directo, cero reimplementacion) y devuelve exactamente su misma salida de 5 secciones. Exit code igual al de `test-checks.ps1` (1 si `quality_approval` fallo, 2 si `quality_approval.status: "requires-agent"`).

## Reporte

Cada `--check` imprime su JSON. Exit code: 0 = pass sin agente pendiente; 1 = bloqueado deterministicamente (`fuera_de_alcance[]` no vacio, o `quality_approval.status: "failed"` heredado de `test-checks.ps1`); **2 = requires-agent** (`scope_enforcer`/`traceability_watcher` presente en `unintended-change-detector`/`plan-to-code-traceability`, o `quality_approval.status: "requires-agent"` en `correctness-chain`).

Con exit 2, el script **nunca vuelve a evaluarse** — quien invoca este skill despacha el agente nombrado en `agente`/`instruccion` y su VEREDICTO (`VERDICT: pass|blocked`) es el resultado final de esa capa, exactamente igual que ya documenta `skills/plan-checks/SKILL.md:38-42` para sus 2 gates semanticos. Reporte final combinado: determinista limpio + agente `pass` → PASS; determinista bloqueado O agente `blocked` → FAIL citando la razon concreta (la `razon`/`fuera_de_alcance` del script, o el `reason` literal del agente).

## Scope global (pendiente)

El flag `-Scope global` existe en la firma del dispatcher pero ningun `--check` de este increment implementa logica de scope global todavia — se extiende mas adelante (`unintended-change-detector -Scope global`, campo `contexto_global_consultado[]`).
