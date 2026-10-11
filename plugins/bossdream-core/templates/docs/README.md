# Documentacion

Estructura Diataxis: cada archivo pertenece a **un solo** modo. No mezclar.

| Carpeta | Modo | Orientacion |
|---|---|---|
| `human-explanations/` | Human explanation | Aprender de la mano (onboarding) |
| `to-skills/` | To-skill | Resolver una tarea concreta |
| `catalog/` | Catalog | Descripcion sistematica (API, config, esquema) |
| `concepts/` | Concept | Por que, trade-offs, contexto |

Otras carpetas:
- `_inbox/` — buzon de notas informales; `/docs-rewrite` las procesa a los 4 modos.
- `adr/` — Architecture Decision Records (MADR), inmutables.
- `architecture/` — diagramas C4 (Mermaid).

Las plans ejecutables (`.feature` Gherkin) viven en `plans/`, no aqui.
