# BossDream

Plugins de Claude Code que hacen cumplir la calidad con hooks (scripts que ejecuta Claude Code) en vez de depender del prompt. El agente no puede dar una tarea por terminada hasta que el pipeline y los criterios de cierre estén en verde, con evidencia.

**Documentación completa** (comandos, skills, agentes, flujos, templates, MCP): https://miguelalrendon.github.io/BossDream/

## Plugins

| Plugin | Qué aporta |
|---|---|
| `bossdream-core` | El motor: comandos, skills, agentes, hooks, plantillas de proyecto, 11 MCP con versión fijada y la gobernanza de documentos de negocio. Es obligatorio. |
| `bossdream-dotnet` | Pack de lenguaje .NET: `pipeline.json`, CI y `.editorconfig`. |
| `bossdream-nodejs` | Pack de lenguaje Node/TypeScript: lo mismo para npm. |

Se instala `bossdream-core` y exactamente un pack de lenguaje por proyecto.

## Requisitos

| Requisito | Detalle |
|---|---|
| Claude Code | Con soporte de plugins, hooks y skills. |
| PowerShell 7 (`pwsh`) | Windows, Linux y macOS. Los hooks se ejecutan con `pwsh`. |
| Node.js y `uv` | Los MCP se lanzan con `npx` y, solo Serena, con `uvx`. |
| Probado en | Windows (PowerShell 5.1 y 7) y Ubuntu. macOS no se ha probado. |

## Instalación

```bash
/plugin marketplace add MiguelALRendon/BossDream
/plugin install "bossdream-core"@bossdream
/plugin install "bossdream-dotnet"@bossdream   # o bossdream-nodejs
/reload-plugins
```

Después, en tu proyecto, ejecuta `/bossdream-init` (repositorio existente) o `/bossdream-new` (proyecto nuevo).

## Estado

Versión 1.0.0 (`bossdream-dotnet` y `bossdream-nodejs`: 0.1.0). Cambios en [`CHANGELOG.md`](CHANGELOG.md); deuda conocida en [`docs/TECH_DEBT.md`](docs/TECH_DEBT.md).

## Desinstalar o desactivar

- Desinstalar: `/plugin uninstall "bossdream-core"@bossdream`.
- Saltar un gate una vez, con traza: `/pipeline skip --reason "…"`.

## Créditos

Cada herramienta conserva su licencia; BossDream solo las orquesta.

| Tipo | Herramientas |
|---|---|
| MCP incluidos | [sequentialthinking](https://github.com/modelcontextprotocol/servers), [context7](https://github.com/upstash/context7), [fetch](https://github.com/zcaceres/fetch-mcp), [codebase-memory](https://github.com/DeusData/codebase-memory-mcp), [playwright](https://github.com/microsoft/playwright-mcp), [dbhub](https://github.com/bytebase/dbhub), [a11y](https://www.npmjs.com/package/a11y-mcp), [mdn](https://www.npmjs.com/package/mdn-mcp), [colors](https://www.npmjs.com/package/@colorsandfonts/mcp), [mermaid](https://github.com/hustcc/mcp-mermaid), [serena](https://github.com/oraios/serena) |
| Pipeline .NET | [.NET SDK](https://dotnet.microsoft.com), [NetArchTest](https://github.com/BenMorris/NetArchTest), [coverlet](https://github.com/coverlet-coverage/coverlet), [Reqnroll](https://reqnroll.net), [Playwright](https://playwright.dev/dotnet), [Stryker.NET](https://stryker-mutator.io) |
| Pipeline Node | [TypeScript](https://github.com/microsoft/TypeScript), [Prettier](https://prettier.io), [dependency-cruiser](https://github.com/sverweij/dependency-cruiser), [Vitest](https://vitest.dev), [Cucumber.js](https://github.com/cucumber/cucumber-js), [Playwright](https://playwright.dev), [StrykerJS](https://stryker-mutator.io) |
| Metodologías | [Diátaxis](https://diataxis.fr), [ADR/MADR](https://adr.github.io/madr), [C4](https://c4model.com), [Gherkin](https://cucumber.io/docs/gherkin), [Living Documentation](https://leanpub.com/livingdocumentation) |
| Host | [Claude Code](https://code.claude.com), [Model Context Protocol](https://modelcontextprotocol.io), [Anthropic](https://www.anthropic.com) |
