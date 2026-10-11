# Tech Debt Ledger

> Running register of technical debt found by the `tech-debt` skill. **Advisory only — nothing here blocks a build or a plan.** Update `Status` as items are paid down.
>
> Status values: `open` · `in-progress` · `paid` · `wont-fix`. Effort: `low` · `medium` · `high`.

| ID | Location | Category | Impact | Remediation | Effort | Status |
|----|----------|----------|--------|-------------|--------|--------|
| TD-001 | `templates/bossdream.json` vs `scripts/sync-agent-models.ps1` | consistencia | La plantilla define `models.plan/code/audit/quick`; el script lee `models.default/agents` y solo actua sobre `plugins/bossdream-core/agents` del propio repo | Unificar el esquema y decidir si el script es herramienta del framework o de proyectos | medium | open |
| TD-002 | hooks de `.claude/bossdream-hooks/` | portabilidad | Los hooks se copian al proyecto con `/bossdream-init`; moverlos a `hooks/hooks.json` del plugin evitaria la copia y el drift, pero obliga a rehacer la resolucion de scripts hermanos (`plugin-paths.psm1` busca `<proyecto>/plugins`) | Redisenar con `${CLAUDE_PLUGIN_ROOT}` y migrar las pruebas de hermanos | high | open |
| TD-003 | `scripts/*.ps1` | encoding | Varios `Get-Content` sin `-Encoding utf8` leen mal UTF-8 sin BOM en Windows PowerShell 5.1 | Fijar `-Encoding utf8` en las lecturas o dejar PowerShell 7 como unico host | low | open |
| TD-004 | regla de comentarios | experiencia | La regla solo llega al proyecto con `/bossdream-init` (`.claude/rules/comentarios.md`) | Inyectarla con un hook `SessionStart` del plugin cuando exista `hooks.json` (TD-002) | low | open |
| TD-005 | `scripts/plan-lock.ps1`, `readiness.ps1` | seguridad | El mode-lock lee `.claude/.work-mode` de `cwd` del payload: si la sesion tiene como directorio de trabajo una subcarpeta del proyecto, no encuentra el archivo y el bloqueo no se aplica (observado en esta sesion al editar `.ps1` desde `plugins/bossdream-core`) | Resolver la raiz del proyecto con `CLAUDE_PROJECT_DIR` o subiendo hasta encontrar `.claude/` | medium | open |
