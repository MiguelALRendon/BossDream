# bossdream-core

Motor agnostico de dominio del framework BossDream + gobernanza de documentos de negocio del SDLC.

## Contenido

- **skills**: `bossdream` (Delivery Cycle), `docs-rewrite` (docs IA-friendly), `pipeline`, `plan-new`, `adr-new`, `rules-comentarios`, `validation-run`, `validation-exemption-advisor`, `epic-planner`, `flow-test-gen`, `traceability-sync`.
- **agents**: `bossdream-solid-auditor`, `bossdream-design-auditor`, `bossdream-endless-verifier` (veredicto estructurado, modelo barato), `bossdream-document-auditor`, `bossdream-document-explorer` (identifica objetos de un increment y busca skills existentes que apliquen, sin decidir ni escribir nada — se despacha en `/bossdream-plan` Paso 5), `bossdream-completeness-auditor` (investiga con `WebFetch` los requisitos duros de sistemas/dominios externos que un plan integra y los cruza contra `spec.md`/`plan.md`, sin decidir si algo ambiguo es obligatorio — se despacha UNA VEZ en el Cierre de `/bossdream-plan` Paso 6).
- **hooks** (`scripts/`, se instalan en el proyecto con `/bossdream-init`, no vía el plugin): comment-check (PreToolUse), command-lock (PreToolUse), read-budget (PreToolUse, opt-in), readiness (UserPromptSubmit), stop-completion (Stop).
- **templates**: capa de proyecto que `/bossdream-init` materializa, más `_PROJECT_TEMPLATE/` para `bossdream_projects/<proyecto>/`.
- **.mcp.json**: set curado de MCP (sequentialthinking, context7, fetch, codebase-memory, playwright, dbhub, a11y, mdn, colors, mermaid, serena). Requiere Node (`npx`) y `uv` (`uvx`, solo serena). `dbhub` arranca solo si se configura `db_dsn` y siempre en solo lectura (`config/dbhub.toml`).

## userConfig (pedido en instalacion)

- `db_dsn` (sensitive, opcional): DSN de una base SQL que `dbhub` consulta en solo lectura.
- `enable_read_budget_hook` (bool): reencamina lecturas/busquedas amplias.

## Nota de arquitectura

Los agents usan MCP de sesion (declarados en `.mcp.json` de este plugin) via su allowlist `tools`; no declaran mcpServers propios (limitacion de plugin agents). El pipeline lee `pipeline.json` del proyecto: el motor es agnostico, los comandos son del stack.

## Gobernanza de proyectos (SDLC)

Gobierna documentos de negocio del SDLC del equipo (`bossdream_projects/<proyecto>/`): understanding, requirements, test approach, y un pipeline de **Document Validation por documento** antes de permitir planear o implementar con `/bossdream-plan`/`/bossdream-implement`. Es parte de este mismo plugin (`commands/`+`skills/`+`agents/`+`scripts/`+`templates/`), agnóstica de stack y de lenguaje.

### Principio de diseño más importante

**`commands/bossdream-plan.md` no se modifica.** La extensión de `/bossdream-plan` para que use el research-log de un proyecto activo se logra con un hook `UserPromptSubmit` adicional (`plan-context-inject.ps1`) que inyecta contexto en runtime — nunca editando el archivo del comando.

### Comandos

| Comando | Estado | Qué hace |
|---|---|---|
| `/bossdream-project <contexto>` | **Implementado** | Clasifica S/M/C, propone Epics/Features (skill `epic-planner`), crea `bossdream_projects/<proyecto>/` (invoca `project-scaffold.ps1`), genera `requirements.md` (incluida su sección de Reglas de negocio) vía `docs-rewrite`. `overview.md`/`understanding.md` ya no se generan aquí — son reportes bajo demanda, ver `/bossdream-report`. |
| `/bossdream-validate` | **Implementado** | Corre el pipeline de Document Validation batcheado por check, no por documento (skill `validation-run`): cascada `validation-vale-check.ps1` → `validation-structure-check.ps1` → `validation-trace-check.ps1`, y agente `bossdream-document-auditor` en tandas batcheadas para la parte semantica. Solo `validation-check.ps1` puede escribir `overallStatus:"ready"`. |
| `/bossdream-testcase <escenario>` | **Implementado** | Genera un `TC-XXX.md` nuevo, un caso a la vez, aprobado explícitamente antes de registrarse. `testcase-register.ps1` lo enlaza a su US/AC en `traceability.json`, reabre `validation.json` a `blocked`, y actualiza el resumen de `test-approach.md §7`. |
| `/bossdream-update-docs` | **Implementado** | Si hay `alcance_nuevo`, invoca `epic-planner` para integrarlo; siempre invoca `traceability-sync` (regenera `traceability.json` desde los Markdown) y `validation-check.ps1` (descubre documentos nuevos y reabre lo que cambio). |
| `/bossdream-set-active-project [slug\|clear]` | **Implementado** | Activa un proyecto ya existente (para retomar el de otro dev, o cambiar de proyecto para apoyar en otro), lo desactiva (`clear`, vuelve a modo normal — `/bossdream-plan`/`/bossdream-implement` sin gobernanza de proyecto), o informa el estado sin argumento. `.claude/.active-project` es un puntero **local por desarrollador** — `project-scaffold.ps1` lo agrega a `.gitignore`, nunca viaja por git. |
| `/bossdream-report` | **Implementado** | Genera `overview.md`/`understanding.md` del proyecto activo bajo demanda, en `docs/reports/<slug>/` — fuera del alcance de `validation-check.ps1`. Reusa las plantillas de `templates/_PROJECT_TEMPLATE/` a partir de `requirements.md`/`traceability.json`/`tests/test-approach.md`. Nunca lee ni migra un `understanding.md` legado dentro de `bossdream_projects/<slug>/`. |
| `/bossdream-skill-exploration` | **Implementado** | Auditoria completa y puntual del catalogo de skills (skill `skill-exploration`): mapea el repo con `repo-map`, corre `tech-debt` a nivel de todo el proyecto, y disena con el usuario via `brainstorming` cada skill nueva/actualizada que `tech-debt` confirme como duplicacion real. |

### QA Increment

**Implementado.** La skill `flow-test-gen` genera el catálogo combinatorio de Pruebas de Flujo (*all-transitions*/*round-trip coverage*, ISTQB) para el QA Increment — el penúltimo paso del increment (mismo lugar donde `test-gen` ya se invoca en cualquier increment normal), sin modificar `commands/bossdream-implement.md`. Se autoverifica con `scripts/flow-coverage-check.ps1` (determinístico: cuenta transiciones esperadas vs. cubiertas) antes de presentar los casos al usuario uno por uno.

`/bossdream-plan` y `/bossdream-implement` no cambian de comando — su comportamiento se extiende vía hooks:

| Hook | Estado | Evento | Qué hace |
|---|---|---|---|
| `validation-lock.ps1` | **Implementado** | `UserPromptSubmit` (entrada adicional) | Bloquea `/bossdream-plan`/`/bossdream-implement` cuando hay proyecto activo y `validation.json.overallStatus == "blocked"`. |
| `plan-context-inject.ps1` | **Implementado** | `UserPromptSubmit` (entrada adicional) | Con proyecto activo + `validation.json` en `"ready"`, inyecta el research-log del proyecto + conteo de Epics/Features + tamaño sugerido (pequeño/grande/monstruo) + instrucciones de cierre (`plan-progress-update.ps1`, rollup `roadmap.md`). Con `blocked`/sin match/sin proyecto: no imprime nada. |
| `mark-project-dirty.ps1` | **Implementado** | `PostToolUse` (entrada adicional, matcher `Edit\|Write\|MultiEdit`) | Marca `pending` el documento especifico editado a mano — solo si ya estaba registrado en `validation.json`; archivos nuevos requieren `/bossdream-update-docs`. |
| `project-sync.ps1` | **Implementado** | `Stop` (entrada adicional) | Con proyecto activo, corre `traceability-build.ps1` y `validation-check.ps1` al cerrar el ciclo — sin proyecto activo, no toca nada. `validation-check.ps1` se invoca via `${CLAUDE_PLUGIN_ROOT}/scripts/` (no la copia de `bossdream-hooks/`) porque resuelve su `PluginRoot`/`templates/` desde su propia ubicacion. |

Los 4 hooks se copian a `.claude/bossdream-hooks/` y se **fusionan** (nunca reemplazan) en `.claude/settings.json` via `project-scaffold.ps1`.

### Pruebas de gobernanza de proyectos

`tests/*.Tests.ps1` (Pester 5+, ejecutan junto al resto de la suite del plugin) cubren `validation-*`, `flow-*`, `*-project*`, `traceability-*`, `testcase-register`, `set-active-project`, `rollup-template` y `gitignore-merge`.

Nota de alcance: los comandos/skills (`.md`) se prueban a nivel estructural (frontmatter, referencias correctas) — el juicio de clasificación S/M/C y la propuesta de Epic/Feature es comportamiento dirigido por prompt (Claude leyendo `bossdream-project.md`/`epic-planner/SKILL.md`), no código determinista, y se valida por revisión de diseño + dry-run manual, no por test automatizado.

**Nota de encoding (Windows PowerShell 5.1):** cualquier `.ps1`/`.Tests.ps1` cuyo *código fuente* (no los datos que procesa) contenga acentos/emes-rayas debe guardarse con BOM UTF-8 — sin BOM, el parser cae al codepage del sistema y corrompe tokens (`—` puede volverse un caracter que rompe strings). Igualmente, la *lectura en runtime* de archivos con texto acentuado (plantillas `.md`, `validation-rules.json`) debe forzarse con `[System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)` en vez de `Get-Content -Raw` a secas.

## Instalación

```
/plugin install bossdream-core --marketplace MiguelALRendon/BossDream
```
