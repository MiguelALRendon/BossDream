# Changelog

## 1.0.0

- Tres plugins publicados en kebab-case: `bossdream-core`, `bossdream-dotnet`, `bossdream-nodejs`.
- `bossdream-core` distribuye 11 MCP con versión fijada: sequentialthinking, context7, fetch, codebase-memory, playwright, dbhub (solo lectura, DSN opcional en `userConfig`), a11y, mdn, colors, mermaid y serena. Los agentes los usan con `mcp__plugin_bossdream-core_<servidor>`.
- Cada increment de un plan lleva `Verificacion funcional:` y el plan termina con un QA Increment. Modo de QA persistente con `/bossdream-qa-mode` (`bossdream.json > qa.mode`, default `costoso`).
- `smoker` ejercita UI con Playwright y confirma datos con dbhub.
- Hooks y scripts portables: PowerShell 7 (`pwsh`) en Windows, Linux y macOS. Suite Pester del plugin verde en Windows PowerShell 5.1, PowerShell 7 y Linux.
- CI con matriz `windows-latest` y `ubuntu-latest`.
- Se eliminaron las dependencias a documentos de diseño que no viajan en el repo, A-Malia, `dxdocs` y `deep-research`.
