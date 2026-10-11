window.FLOWS = [
  {
    id: 'new',
    title: '/bossdream-new',
    tagline: 'Crea un proyecto desde cero con BossDream desde el primer día.',
    entra: ['`/bossdream-new <nombre> <idea>`, donde la idea puede ser texto o un archivo de requerimientos.', 'Una carpeta vacía o casi vacía. Para un proyecto que ya existe se usa `/bossdream-init`.'],
    llama: ['Ofrece `git init` si la carpeta no es un repositorio.', '`brainstorming` y `arch`: definen el objetivo, la arquitectura y el stack, que elige el usuario y nunca se asume.', 'Scaffold guiado: usa la receta del stack-pack si existe; si no, indica al usuario el comando nativo (`dotnet new`, `npm create`…) y espera.', '`/bossdream-init` sobre lo recién creado, para que `planLock.requirePaths`, `testing.project` y `style.themeSource` se llenen con rutas reales.', 'Opcional: `/bossdream-plan` para la primera funcionalidad.'],
    sale: ['Repositorio con la estructura del stack, un proyecto de pruebas y, si hay UI, un archivo de tema.', 'Capa de BossDream instalada: `docs/`, `plans/`, `bossdream.json`, `pipeline.json`, `completion.json`, `.editorconfig`, CI y hooks.', '`docs/constitution.md` es opcional y se puede completar después.'],
    mermaid: `flowchart TD
  A["/bossdream-new nombre idea"] --> B{"Es repo git?"}
  B -->|"no"| C["Ofrece git init"]
  B -->|"si"| D["brainstorming + arch"]
  C --> D
  D --> E["Stack elegido por el usuario"]
  E --> F{"Hay receta en el stack-pack?"}
  F -->|"si"| G["Scaffold con la receta"]
  F -->|"no"| H["Indica el comando nativo y espera"]
  G --> I["/bossdream-init sobre el proyecto nuevo"]
  H --> I
  I --> J["requirePaths, testing.project y themeSource con rutas reales"]
  J --> K["Primera funcionalidad opcional: /bossdream-plan"]`
  },
  {
    id: 'init',
    title: '/bossdream-init',
    tagline: 'Instala BossDream sobre un repo que ya existe.',
    entra: ['El comando `/bossdream-init` dentro del repo.', 'Un stack-pack instalado (`bossdream-dotnet` o `bossdream-nodejs`), o ninguno.'],
    llama: ['Verifica `pwsh`, `node` y `uv` (solo avisa).', 'Inventaría `docs/`, `plans/`, `.claude/`, `CLAUDE.md`.', 'Detecta el stack-pack por `enabledPlugins`.', 'Copia los `*.ps1` y `*.psm1` a `.claude/bossdream-hooks/`.', 'Fusiona `settings.json` (hooks con `pwsh`, plugins, marketplace).', 'Copia solo lo que falta desde `templates/`.', 'Propone `planLock.requirePaths` y el proyecto de pruebas.'],
    sale: ['Capa de proyecto lista: `docs/`, `plans/_TEMPLATE/`, `pipeline.json`, `completion.json`, `bossdream.json`, CI.', 'Guía de llenado: `docs/constitution.md` y `docs/_inbox/`.'],
    mermaid: `flowchart TD
  A["/bossdream-init"] --> B{"Requisitos: pwsh, node, uv"}
  B --> C["Inventario del repo"]
  C --> D{"Stack-pack instalado?"}
  D -->|"uno"| E["Templates del pack"]
  D -->|"ninguno"| F["pipeline.json minimo + aviso"]
  D -->|"varios"| G["Pregunta al usuario"]
  E --> H["Copia hooks .ps1 y .psm1"]
  F --> H
  G --> H
  H --> I["Fusiona settings.json"]
  I --> J["Copia templates que faltan"]
  J --> K["Propone planLock y proyecto de pruebas"]
  K --> L["Guia de llenado"]`
  },
  {
    id: 'plan',
    title: '/bossdream-plan',
    tagline: 'De una historia cruda a un plan por increments. Modo no editable.',
    entra: ['Una historia cruda en palabras del usuario.', 'El hook `readiness` fija `.claude/.work-mode = plan`.'],
    llama: ['Triage: trivial, una task o deep-plan.', 'Clasifica: modify-flow, add-to-flow o new.', 'Investiga con `ctx`, codebase-memory, Serena, `fetch`, `context7` y llena el research-log.', 'Impacto cross-flow y `tech-debt` informativo.', 'Propone 2 o 3 opciones con `brainstorming`.', 'Por increment: `bossdream-document-explorer`, revisión de diseño, `plan-checks`.', 'Añade siempre el QA Increment al final.', '`bossdream-completeness-auditor` una vez y `/adr-new`.'],
    sale: ['`plans/<feature>/{spec.md, design.md, plan.md}` con fuente y porqué por paso.', 'Mensaje de cierre: "Plan completo. Para ejecutarlo, corre `/bossdream-implement`".'],
    mermaid: `flowchart TD
  A["/bossdream-plan historia"] --> B["Hook readiness: modo plan"]
  B --> C{"Triage"}
  C -->|"trivial"| D["Responde directo"]
  C -->|"task o grande"| E["Clasifica y investiga"]
  E --> F["Impacto cross-flow + tech-debt"]
  F --> G["2-3 opciones: brainstorming"]
  G --> H["Redacta increment"]
  H --> I["document-explorer"]
  I --> J{"Revision de diseno"}
  J -->|"falla"| H
  J -->|"pasa"| K["Escribe en plan.md"]
  K --> L{"Mas increments?"}
  L -->|"si"| H
  L -->|"no"| M["QA Increment final"]
  M --> N["completeness-auditor + adr-new"]
  N --> O["Usuario corre /bossdream-implement"]`
  },
  {
    id: 'implement',
    title: '/bossdream-implement',
    tagline: 'Ejecuta el plan un increment a la vez y se detiene a pedir permiso.',
    entra: ['Un `plan.md` completo. Solo lo corre el usuario.', 'El hook cambia el modo a `implement`.'],
    llama: ['`bossdream-coder` para los pasos de código.', '`test-gen` (y `gherkin-gen` si cambia un flujo) y `docs-rewrite` para el doc-check.', '`pipeline.ps1` con las etapas del increment.', '`bossdream-smoker` ejecuta la `Verificacion funcional:` con Playwright o dbhub.', '`bossdream-solid-auditor` sobre el código tocado.', '`bossdream-design-auditor` si hubo UI.', 'Hasta `maxBlocks` reintentos; después, handoff.'],
    sale: ['Informe de cambios por archivo con su justificación.', 'Pausa para pedir permiso antes del siguiente increment.', 'Al terminar: `bossdream-endless-verifier`, modo vuelve a `plan` y nunca hace commit.'],
    mermaid: `flowchart TD
  A["/bossdream-implement"] --> B["Toma increment pendiente"]
  B --> C["coder implementa pasos"]
  C --> D["test-gen + docs-rewrite"]
  D --> E["pipeline.ps1"]
  E --> F["smoker: verificacion funcional"]
  F --> G["solid-auditor"]
  G --> H{"UI tocada?"}
  H -->|"si"| I["design-auditor"]
  H -->|"no"| J{"Todo verde?"}
  I --> J
  J -->|"no"| K{"Reintentos < maxBlocks"}
  K -->|"si"| C
  K -->|"no"| L["Handoff al usuario"]
  J -->|"si"| M["Informe de cambios"]
  M --> N{"Permiso del usuario"}
  N -->|"siguiente"| B
  N -->|"fin"| O["endless-verifier y modo plan"]`
  },
  {
    id: 'qa',
    title: 'QA Increment',
    tagline: 'Último increment de todo plan: verifica el comportamiento de lo implementado.',
    entra: ['El QA Increment del plan, con el modo de `bossdream.json > qa.mode`.', 'Un Test Inventory vigente o la orden de generarlo.'],
    llama: ['`bossdream-qa-gatekeeper` genera el Test Inventory.', '`test-checks`: chequeos deterministas.', '`bossdream-qa-planner`: primer veredicto.', '`qa-run` en `optimo`, `agresivo` o `costoso` si hubo rechazo.', '`bossdream-qa-auditor` intenta refutar las pruebas.', '`bossdream-qa-planner` da el veredicto final.'],
    sale: ['Veredicto ACCEPTED o REJECTED.', 'Evidencia propia siempre, y el gate `qa-manager` del Completion Criteria.'],
    mermaid: `flowchart TD
  A["QA Increment"] --> B["Test Inventory: qa-gatekeeper"]
  B --> C["Test Checks deterministas"]
  C --> D["qa-planner: primera pasada"]
  D --> E{"Veredicto"}
  E -->|"ACCEPTED"| H["Evidencia"]
  E -->|"REJECTED"| F["qa-run: remediacion"]
  F --> G["qa-auditor refuta la suite"]
  G --> I["qa-planner: veredicto final"]
  I --> H`
  },
  {
    id: 'stop',
    title: 'Completion Criteria',
    tagline: 'Verificación que se ejecuta al cerrar cada turno.',
    entra: ['Cada turno que edita código: `mark-dirty` crea `.bossdream-dirty`.', 'El evento Stop de Claude Code.'],
    llama: ['`stop-completion.ps1` lee `completion.json`.', 'Gate `pipeline`: corre `pipeline --local`.', 'Gate `tasks`: `tasks-complete`.', 'Gate `qa-manager`: `bossdream-qa-planner` cuando hay QA Increment.', 'Gates opcionales: evidencia y `bossdream-endless-verifier`.'],
    sale: ['Todo verde: el turno cierra con `pipeline OK`.', 'Algo rojo: `decision: block` con la etapa rota.', 'A los 8 intentos: escala al usuario con un reporte, nunca un pase silencioso.'],
    mermaid: `flowchart TD
  A["Edit o Write de codigo"] --> B["mark-dirty: marcador"]
  B --> C["Claude intenta cerrar el turno"]
  C --> D["Hook Stop: stop-completion"]
  D --> E{"Hay marcador?"}
  E -->|"no"| F["Cierra sin correr nada"]
  E -->|"si"| G["Gates de completion.json"]
  G --> H{"Todo en verde?"}
  H -->|"si"| I["Cierra: pipeline OK"]
  H -->|"no"| J{"Intento < 8"}
  J -->|"si"| K["Block: el agente corrige"]
  K --> C
  J -->|"no"| L["Escala al usuario con reporte"]`
  },
  {
    id: 'hooks',
    title: 'Hooks de enforcement',
    tagline: 'Verificaciones que el harness aplica en cada acción del agente.',
    entra: ['Cada prompt, cada edición, cada comando Bash y cada lectura.'],
    llama: ['`readiness` (UserPromptSubmit): fija el modo y recuerda `plans/`.', '`plan-lock` (PreToolUse): niega editar código en modo no editable o sin spec en rutas de dominio.', '`comment-check` (PreToolUse): niega comentarios prohibidos.', '`command-lock` (PreToolUse): niega `git reset --hard`, `push --force`, `rm -rf /`.', '`read-budget` (PreToolUse, opcional): reencamina lecturas amplias.', '`mark-dirty` y `sync-agent-models` (PostToolUse).'],
    sale: ['Una acción permitida, o un `deny` con la razón para que el agente reescriba.'],
    mermaid: `flowchart LR
  P["Prompt"] --> R["readiness: modo"]
  R --> A["Agente decide una accion"]
  A --> E["Edit o Write"]
  A --> B["Bash"]
  A --> L["Read o Grep"]
  E --> PL["plan-lock"]
  PL --> CC["comment-check"]
  B --> CL["command-lock"]
  L --> RB["read-budget"]
  PL -->|"deny"| X["Agente reescribe"]
  CC -->|"deny"| X
  CL -->|"deny"| X
  CC -->|"ok"| W["Se ejecuta"]
  W --> MD["mark-dirty"]`
  },
  {
    id: 'gov',
    title: 'Gobernanza de documentos',
    tagline: 'Del contexto de negocio a un Document Validation en "ready".',
    entra: ['Contexto de negocio en `/bossdream-project <contexto>`.'],
    llama: ['Clasifica S, M o C y propone Epics y Features con `epic-planner`.', '`project-scaffold.ps1` crea `bossdream_projects/<proyecto>/`.', '`docs-rewrite` genera `requirements.md`.', '`/bossdream-testcase` añade `TC-XXX.md` de uno en uno.', '`/bossdream-validate` corre `validation-run`: vocabulario, estructura, trazabilidad y `bossdream-document-auditor`.', '`validation-lock` y `plan-context-inject` condicionan `/bossdream-plan`.'],
    sale: ['`validation.json` con `overallStatus: ready`.', 'Con `ready`, `/bossdream-plan` recibe el research-log del proyecto.', 'Con `blocked`, `/bossdream-plan` y `/bossdream-implement` quedan bloqueados.'],
    mermaid: `flowchart TD
  A["/bossdream-project"] --> B["Clasifica S, M o C"]
  B --> C["epic-planner propone Epics y Features"]
  C --> D["project-scaffold"]
  D --> E["requirements.md via docs-rewrite"]
  E --> F["validation.json: blocked"]
  F --> G["/bossdream-validate"]
  G --> H["Vale, estructura, trazabilidad"]
  H --> I["document-auditor semantico"]
  I --> J{"Hallazgos?"}
  J -->|"si"| K["Corregir y revalidar"]
  K --> G
  J -->|"no"| L["overallStatus: ready"]
  L --> M["/bossdream-plan recibe el research-log"]`
  }
];
