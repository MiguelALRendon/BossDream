---
name: bossdream-sync
description: Reconcilia los archivos gestionados por el framework (wiring de hooks en settings, plantillas de pipeline/completion, esqueletos de docs) con la version actual del plugin, sin tocar el contenido del equipo ni del usuario.
disable-model-invocation: true
---

# /bossdream-sync — sincronizar con la version del plugin

Actualiza solo lo gestionado por el framework tras un update del plugin.

## Pasos

1. Comparar `${CLAUDE_PLUGIN_ROOT}/templates/` contra el proyecto.
2. Reconciliar **solo archivos gestionados**: **refrescar `.claude/bossdream-hooks/*.ps1`** desde `${CLAUDE_PLUGIN_ROOT}/scripts/`; el bloque `hooks` y `enabledPlugins`/`extraKnownMarketplaces` en `.claude/settings.json`; estructura de `docs/`; `ci/quality-gate.yml`. Añadir/actualizar lo gestionado; no pisar permisos, thresholds ni contenido del equipo.
3. **No tocar** contenido del usuario: `CLAUDE.md`, `constitution.md`, `docs/{human-explanations,to-skills,catalog,concepts}/`, `docs/adr/`, `plans/`.
4. Reportar en un diff resumido que cambio y registrar la version sincronizada (sugerir un ADR si cambio un gate).

## Reglas

- Ante conflicto entre plantilla y contenido del equipo, gana el equipo; solo se reporta la diferencia.
- Idempotente.
