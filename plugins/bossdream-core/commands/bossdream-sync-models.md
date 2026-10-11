---
name: bossdream-sync-models
description: Sincroniza el `model:` del frontmatter de cada agente en `plugins/bossdream-core/agents/` con `bossdream.json > models`. Ya corre automatico via hook al editar bossdream.json; este comando lo fuerza a mano.
disable-model-invocation: true
---

# /bossdream-sync-models — sincronizar modelos de agentes a mano

## Pasos

1. Invoca `scripts/sync-agent-models.ps1 -ProjectDir <ruta del repo>`.
2. Muestra la salida del script tal cual, sin resumirla ni reinterpretarla.
