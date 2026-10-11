---
name: context-router
description: Protocolo de economia de contexto — antes de leer un archivo completo, escala por niveles baratos primero (artefacto, resumen, mapa, simbolo, rango) y solo cae a archivo completo si ninguno responde. No es un comando que se invoca aparte, es una disciplina que toda skill/agente sigue cuando va a leer codigo o documentos. Registra cada consulta resuelta (en cualquier nivel) via context-router-log.ps1; solo el nivel archivo_completo carga una razon. TRIGGER — implicito, en cualquier punto donde una skill/agente este por hacer Read directo de un archivo completo.
---

# context-router — cascada de adquisicion de contexto

No es un comando. Es el orden en el que cualquier skill/agente de este plugin debe intentar responder "¿que hace X?" antes de pagar el costo de un `Read` completo.

## La cascada

1. **Artefacto** — ¿ya existe un artefacto estructurado que responde esto sin interpretar nada? (`.bossdream-project/artifacts/**/*.artifact.json`, `validation.json`, `traceability.json`, `plan.md` con checkboxes). Si el dato ya esta ahi como campo, no hay nada que leer.
2. **Resumen** — ¿un resumen ya generado cubre la pregunta? (el resumen minimo que `plan-context-inject.ps1` inyecta: nombre, `overallStatus`, conteo de AC/TC — no el proyecto completo).
3. **Mapa** — ¿`.bossdream-project/repo-map.json` o `codebase-memory` (`get_architecture`/`search_graph`) ya indexan el simbolo/archivo en cuestion?
4. **Simbolo** — ¿se puede resolver con `codebase-memory` (`get_code_snippet`, `trace_path`) o un `Grep` puntual del nombre del simbolo, sin abrir el archivo entero?
5. **Rango** — ¿`Grep` ya localizo la linea? Entonces `Read` con `offset`/`limit` acotado a esas lineas, no el archivo completo.
6. **Archivo completo** — ultimo recurso. Se permite, pero se registra con `scripts/context-router-log.ps1` (ver abajo).

Cada nivel que falla (no responde la pregunta) es la razon por la que se escala al siguiente. El log es de una linea JSON por consulta, no solo las que terminan en archivo completo (toda adquisicion de contexto, en cualquier nivel, queda atada a una tarea). Solo la escalada a archivo completo carga una razon (`motivo_escalada`); en cualquier otro nivel el campo es `null` porque el nivel que respondio ES la razon (no hizo falta escalar mas).

## Donde ya se aplica esta disciplina en este mismo repo (sin llamarse asi)

El principio no es nuevo — ya existe en tres lugares como caso concreto de "barato antes que caro", solo que aplicado a ejecucion en vez de a lectura de contexto:

- **`validation-run`** (`skills/validation-run/SKILL.md`, paso 2): corre `validation-check.ps1` (deterministico) ANTES de invocar el agente `bossdream-document-auditor` (semantico, caro). Documentos que fallan en la pasada barata "van directo a la lista de hallazgos, sin agente" — nunca se paga el costo semantico si el costo determinista ya respondio.
- **`ctx`** (`skills/ctx/SKILL.md`, item 1): ya pide "los 3-5 archivos mas relevantes con path exacto y las lineas a leer (`archivo.ext:50-120`), no el archivo completo" — es literalmente el escalon 5 (rango) de esta cascada, aplicado hoy sin que existiera un nombre formal para el protocolo completo ni un registro de cuando se incumple.
- **`tech-debt`** (`skills/tech-debt/SKILL.md`, "Alcance"): "para scopes grandes, delega la lectura a un subagente (Explore) para no gastar el contexto principal; trae solo las conclusiones" — evita que el archivo completo entre al contexto principal aunque alguien tenga que leerlo en algun punto.

`context-router` formaliza el mismo reflejo para el caso general de lectura de contexto y le agrega lo que faltaba: registro de cuando el escalon barato NO alcanzo, algo que ninguno de los tres ejemplos de arriba hace hoy.

## Registrar una consulta

Cada vez que la cascada resuelve una pregunta, sin importar en que escalon — el contrato es "una linea por consulta", no solo por escalada. El caller pasa el escalon donde realmente se resolvio:

```
pwsh -File scripts/context-router-log.ps1 -ProjectDir <ruta del proyecto> -Pregunta "<la pregunta original>" -NivelAlcanzado <artefacto|resumen|repo-map|simbolo|rango|archivo_completo> -TareaAsociada "<id o descripcion de la tarea>"
```

El unico nivel que agrega una razon (`motivo_escalada`) es `archivo_completo` — ahi el script fija automaticamente el texto literal del contrato, el caller no lo pasa como texto libre. En los otros 5 niveles `motivo_escalada` queda `null`.

## Contrato del log

Schema en `scripts/context-router-log.ps1` (`.bossdream-project/context-router.log`, JSON Lines). El archivo se escribe en UTF-8 sin BOM (compatible con `jq`/lectores JSON estrictos); cualquier lectura desde PowerShell debe usar `Get-Content -Encoding utf8` explicito — el default de Windows PowerShell 5.1 sin BOM cae al codepage del sistema y corrompe los caracteres acentuados del `motivo_escalada` fijo.

## Reglas

- Nunca saltar directo a "archivo completo" cuando un escalon anterior no se intento — el orden es fijo, no opcional.
- El registro es obligatorio en toda consulta resuelta, no solo en las que llegan a archivo completo.
- No inventar una razon distinta a la fijada por el contrato (`motivo_escalada` es una cadena literal fija cuando se llega a archivo completo, no texto libre) — el detalle de *que* escalones se probaron antes vive en la traza de la tarea, no en este log.
