# Plan — <feature>

> Producto de `/bossdream-plan`. Referencia: `spec.md` (QUE), `design.md` (diseno aprobado). **Regla dura: sin placeholders.**

## Razon de ser
<por que existe este plan; el problema/objetivo real>

## Justificacion
<por que este enfoque; alternativas consideradas -> ADR-NNNN>

## Flujo (que / por que)
<narrativa breve de que se hace y por que>

## Clasificacion
tipo: modify-flow | add-to-flow | new   ·   complejidad: trivial | task | large

## Investigacion (research-log)
| Pregunta | Tool/agente | Hallazgo | Como informo el plan |
|---|---|---|---|
|  |  |  |  |

## Impacto cross-flow
| Flujo afectado | Verificado con | ¿Choca? | Mitigacion |
|---|---|---|---|
|  |  |  |  |

## Deuda tecnica (informativa, NO bloqueante)
Hallazgos del skill `tech-debt` sobre los flujos que este plan toca. El usuario decide si se paga (agregando increments) o se deja registrada en `docs/TECH_DEBT.md`. No bloquea el plan.
| Ubicacion | Deuda | Impacto | Remediacion | Esfuerzo | ¿Se paga en este plan? |
|---|---|---|---|---|---|
|  |  |  |  |  |  |

## Decisiones (opcion elegida vs descartadas)
| Decision | Elegida | Descartadas + por que | ADR |
|---|---|---|---|
|  |  |  |  |

## Increments

### Increment 1: <objetivo> — cubre spec [criterios]
- Justificacion / fuentes: <por que este increment; evidencia archivo:linea / query / doc>
- Pasos:
  - [ ] 1.1 <paso codigo>    — skill · mcp · bossdream-coder · fuente: <archivo:linea / doc>
  - [ ] 1.2 <paso no-codigo> — fuente/porque: <...>
  - [ ] 1.y pruebas unitarias — generar/actualizar con test-gen (adversarial primero, happy path al final); solo codigo de logica, respeta exenciones
  - [ ] 1.x doc-check         — revisar/actualizar docs del flujo
- Conexiones: <skills enlazadas o "sin skill aplicable">
- Pipeline del increment: <stages/tests scoped que lo validan>
- Criterio de aceptacion: <verificable>
- Verificacion funcional: navegador (flujo feliz + validaciones rutinarias) | datos (consulta de solo lectura via dbhub) | no aplica: <justificacion en una frase>
- Revision de planeacion: PENDIENTE   (se marca PASO al agregarlo; requiere fuente+porque en cada paso)

### Increment 2: <objetivo>
- Pasos:
  - [ ] 2.1 ...
  - [ ] 2.y pruebas unitarias — test-gen (adversarial primero); solo codigo de logica
  - [ ] 2.x doc-check
- Conexiones: <skills enlazadas o "sin skill aplicable">
- Pipeline del increment: ...
- Criterio de aceptacion: ...
- Verificacion funcional: navegador | datos | no aplica: <justificacion>
- Revision de planeacion: PENDIENTE

### Increment N (ultimo): QA Increment - cubre spec [todos los criterios]
- Pasos:
  - [ ] N.1 skill `qa-increment`: inventario de pruebas, QA Manager, `qa-run` en el modo de `bossdream.json > qa.mode`, Test Critic, re-verificacion
- Conexiones: `qa-increment`, `qa-run`, `bossdream-qa-planner`, `bossdream-qa-auditor`
- Pipeline del increment: `test-checks` en verde con veredicto `QA VERDICT: ACCEPTED`
- Criterio de aceptacion: veredicto ACCEPTED sin razones abiertas
- Verificacion funcional: la ejecuta `qa-run` (Playwright si hay UI, dbhub si hay datos)
- Revision de planeacion: PENDIENTE
