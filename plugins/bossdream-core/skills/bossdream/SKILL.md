---
name: bossdream
description: Delivery Cycle (9 phases) + Simplicity Ladder para desarrollo riguroso en cualquier proyecto. Planificacion (dimensionar contexto + razonamiento estructurado + reto senior + arquitectura), busqueda de contexto en cascada barata, cuestionamiento y reuso, impacto sobre lo establecido, implementacion, auditoria de codigo (bossdream-solid-auditor), auditoria visual (bossdream-design-auditor), re-chequeo final y verificacion en vivo. TRIGGER — invocar ANTES de tocar nada cuando el cambio no es trivial (>1 archivo o >15 lineas netas), hay decision de arquitectura, ambiguedad de interpretacion, o intencion de crear algo nuevo. SKIP — pregunta informativa que no toca codigo, consulta trivial de una linea, o tooling/meta.
---

# Delivery Cycle — enforcement por fase

Toda tarea no trivial pasa por estas fases en orden. Cada fase tiene un dueño; no se salta.

| Fase | Dueño | Dispara cuando |
|---|---|---|
| 0. Dimensionar | Skill `ctx` (cuanto contexto hace falta antes de buscar) | Siempre, primero |
| 1. Planificar | Skill `brainstorming` (diseno aprobado por secciones ANTES de codear) + `arch` (max 2 opciones) + razonamiento estructurado (≥5 componentes) | Peticion no trivial, algo nuevo |
| 2. Buscar contexto | Cascada barata: codebase-memory (grafo) → Serena/LSP (simbolo) → Grep → Read offset+limit. Alcance incierto → delegar a `Explore` | Antes de escribir codigo |
| 3. Cuestionar y reusar | Simplicity Ladder (abajo) | Cualquier propuesta, ambiguedad o intencion de crear algo nuevo |
| 4. Impacto | codebase-memory `trace_path`/`query_graph`; registrar decision via `/adr-new` | Al tocar convencion o codigo legado |
| 5. Implementar | Skills del stack del componente tocado + escalera como lente linea a linea; el tecleo se delega al agente `bossdream-coder` (modelo economico) | Al escribir codigo |
| 6. Auditar codigo | Agente `bossdream-solid-auditor` una vez sobre el conjunto de archivos de la tarea. Excepcion: ≤1 archivo y ≤15 lineas → inline | Al terminar cambios de codigo |
| 7. Auditar diseño/UX | Agente `bossdream-design-auditor` una vez sobre el diff visual. Excepcion: un atributo/clase aislado → inline | Al terminar cambios de markup visual |
| 8. Re-chequear | Releer el diff completo contra lo evaluado en 1/3/5 — ¿sigue siendo el minimo? | Antes de reportar done, si toco >1 archivo |
| 9. Verificar en vivo | Skill `run`/`verify`; el Stop hook corre el pipeline local | UI o comportamiento antes de done |

**Nota Fase 5/6**: el limite de "≤1 archivo y ≤15 lineas → inline" es un criterio de REVISION (cuándo saltar el despacho de `bossdream-solid-auditor` y auditar en el propio turno), a criterio del modelo — no hay un harness tecnico que lo fuerce (`lineBudgetLock` se probo como gate duro en `PreToolUse`/`SubagentStop` y se elimino: dependia de que `agent_type` del `SubagentStop` matcheara un nombre de agente literal, algo que no se sostiene de forma confiable entre sesiones).

## Simplicity Ladder — parar en el primer si

1. ¿Hace falta que exista? → No: no construirlo (YAGNI).
2. ¿Ya existe en el proyecto? → Reusarlo (codebase-memory para confirmar).
3. ¿Lo resuelve la stdlib del lenguaje? → Usarla.
4. ¿Lo resuelve el framework/stack nativo? → Usarlo (revisar skill del componente antes de custom).
5. ¿Lo resuelve una dependencia ya instalada? → Usarla.
6. ¿Cabe en una linea? → Una linea.
7. Solo entonces: el minimo funcional necesario.

Guardrails que nunca se saltan: validacion en boundaries externos, manejo de perdida de datos, seguridad, accesibilidad.

## Arquitectura — no negociable

- Never abstracciones sin ≥3 casos reales que las justifiquen.
- Never clase con mas de una razon de cambio (SRP estricto).
- Never herencia donde composition resuelve lo mismo.
- Never validar entradas internas de codigo propio — solo boundaries externos.
- Never diseñar para requisitos hipoteticos futuros.

## Economia de tokens (transversal)

Enforcement determinista sobre razonamiento: lo que puede hacer un script/hook no se le pide al modelo. Exploracion en cascada (Fase 2). Auditores devuelven veredicto estructurado con `tools` acotado. Nunca releer un archivo recien editado.

## Ruteo de modelos (`bossdream.json` > `models`)

- Fuente de verdad real: `bossdream.json > models` (mapa `agents` con la asignacion explicita por subagente + `categories`/`default` de fallback). El frontmatter `model:` de cada agente en `agents/*.md` es una copia sincronizada, no la fuente.
- Sincronizacion: automatica (hook `PostToolUse` sobre `bossdream.json`) o manual con `/bossdream-sync-models` — corren `sync-agent-models.ps1`, que reescribe solo el `model:` de los agentes cuya entrada difiere y reporta el cambio.
- Cambiar el modelo de un subagente = editar `bossdream.json > models`, no el frontmatter a mano ni un `/model` (eso no aplica a subagentes).
- El modelo del hilo principal es la unica pieza que sigue siendo no negociable via `/model`: el framework no lo cambia por mensaje (no hay hook para eso).

## Planeacion — de idea a plan ejecutable

- Feature o cambio no trivial nuevo → **`brainstorming` primero**: socratico 1-a-1, 2-3 enfoques, aprobacion del diseno **por secciones**, escribe `plans/<feature>/design.md`. No hay codigo antes de la aprobacion.
- Antecede al **Plan Mode nativo** de Claude Code (coexisten): brainstorming acuerda el QUE/diseno; Plan Mode o `/plan-new` estructuran el COMO.
- El `plan.md` pasa una **autorevision antes de implementar**: cobertura spec→tarea (cada criterio tiene tarea), sin placeholders/vaguedad, y **conflict scan** (contradicciones entre tareas/restricciones → una sola pregunta al humano).
- Dos ejes juntos: completitud (nada falta) + sobriedad (nada sobra, Simplicity Ladder).

## Gate de spec (plan-lock)

Antes de editar rutas de dominio (`bossdream.json` > `planLock.requirePaths`), debe existir una spec activa (`/plan-new`) o un modo declarado (`/bossdream-mode spike|research|...`). Investigar, leer o correr casos no dispara el gate. No adivina la intencion: la deciden rutas + modo.

## Completion Criteria

"Done" = evidencia mostrada de que los gates del `completion.json` estan en verde, no la palabra "listo". El Stop hook lo verifica de forma determinista.
