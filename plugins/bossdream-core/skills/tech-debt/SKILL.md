---
name: tech-debt
description: Analiza el codigo que le apuntes (archivo, flujo, modulo) y concluye sobre deuda tecnica — informe priorizado por impacto con remediacion y esfuerzo. Read-only respecto al codigo, NO bloquea ni corre en el pipeline. Registra los hallazgos en el ledger docs/TECH_DEBT.md. TRIGGER — el usuario pide analizar deuda de un objetivo, o el toque NO-obligatorio de /bossdream-plan sobre los flujos que el plan toca.
---

# tech-debt — analisis advisory de deuda tecnica

Herramienta de diagnostico, **no un muro**. Analiza el codigo que el usuario apunte y concluye sobre deuda tecnica. **Nunca bloquea, nunca edita codigo, no corre en el pipeline ni en el Completion Criteria.**

## Alcance
Lo que el usuario apunte: un archivo, un flujo, un modulo, o "la deuda de X". Para scopes grandes, **delega la lectura a un subagente** (Explore) para no gastar el contexto principal; trae solo las conclusiones.

## Que busca (categorias)
- Duplicacion (codigo repetido que deberia consolidarse).
- Complejidad (funciones largas, muchas ramas, anidamiento profundo).
- Acoplamiento rigido / responsabilidades mezcladas (god class/metodo).
- Codigo muerto (no usado, inalcanzable, comentado).
- Marcadores dejados (TODO/FIXME/HACK).
- Valores/strings magicos en logica (no estilos; eso es theme-first).
- Nombres confusos / falta de claridad.
- Patrones obsoletos / API vieja / inconsistencia con las reglas documentadas del proyecto.

## Informe (priorizado por impacto)
Por cada hallazgo: ubicacion (`archivo:linea`), categoria, por que es deuda, riesgo/impacto, **remediacion sugerida**, y **esfuerzo** (bajo/medio/alto). Ordenado de mayor a menor impacto. Concluye y sugiere; **no aplica cambios**.

## Ledger (`docs/TECH_DEBT.md`)
Registra los hallazgos en el ledger: una fila por item, con estado. Al reanalizar, **actualiza estados** (open / in-progress / paid / wont-fix) sin duplicar filas. Es el seguimiento en el tiempo.

## Reglas
- Read-only respecto al codigo: nunca lo edita. Solo escribe/actualiza el ledger (un `.md`).
- No inventes: cada hallazgo ancla a codigo real (`archivo:linea`).
- No es gate: no bloquea planes ni cambios; solo informa.
- No dupliques lo que ya cubren otros: SOLID -> `bossdream-solid-auditor`; estilos -> `theme-first`; pruebas -> `test-gen`.
