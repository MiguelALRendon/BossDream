# Requerimientos Funcionales — [Nombre de la iniciativa]

**ID de iniciativa (Entendimiento):** REQ-XXX
**Clasificación:** Simple / Medio / Complejo
**Vínculo operativo:** [enlace al proyecto/board en Azure DevOps o Wrike]

> **Nota de uso:** el bloque **Epic** solo se instancia si la clasificación es **Complejo**. El bloque **Feature** solo se instancia si es **Medio** o **Complejo**. En **Simple**, se omiten ambos bloques y se va directo a User Story — el proyecto entero se trata como una sola unidad de trabajo.

---

## Reglas de negocio relevantes
- [Regla 1]
- [Regla 2]

---

## Epic — **solo si Complejo** (omitir este bloque en Simple/Medio)

**EPIC-XXX — [Nombre]**
Descripción de la iniciativa grande que agrupa las features siguientes. Propuesta por el agente durante `/bossdream-project` a partir del contexto de entrada, confirmada por el usuario.

---

## Feature — **solo si Medio o Complejo** (omitir este bloque en Simple)

**FEAT-XXX — [Nombre]**
Descripción de la capacidad o bloque funcional. Pertenece a: EPIC-XXX (si aplica clasificación Complejo).

---

## User Stories — siempre presente

### US-XXX — [Nombre corto]
**Pertenece a:** FEAT-XXX (si aplica)
**Prioridad:** Alta / Media / Baja (Value vs. Effort)

> Como [tipo de usuario/rol],
> quiero [acción o capacidad],
> para [beneficio de negocio].

*(Variante técnica, cuando no hay un "usuario" claro — ej. integraciones):*
> El sistema debe [comportamiento esperado], cuando [condición/disparador], para que [resultado de negocio].

**Reglas de negocio aplicables:** [referencia a la sección "Reglas de negocio relevantes" de este documento, si corresponde]

**Dependencias:** [otras US, sistemas externos, aprobaciones pendientes]

#### Criterios de aceptación

- **AC-XXX.1:** [criterio claro, verificable, sin ambigüedad]
- **AC-XXX.2:** [criterio claro, verificable, sin ambigüedad]

*(Usar Given/When/Then solo si el escenario tiene lógica condicional real que lo justifique):*
> Dado que [contexto], cuando [acción], entonces [resultado esperado].

**Pruebas relacionadas:** TC-XXX (ver `tests/cases/`)

---

*(Repetir bloque "User Story" por cada US de la iniciativa)*

---

## Tabla resumen de trazabilidad

> Se sincroniza con `.bossdream-project/traceability.json` — no es la fuente de verdad, es una vista legible. En Simple/Medio se omiten las columnas Epic/Feature que no apliquen.

| Epic | Feature | User Story | AC | Test Case | Prioridad | Estado |
|---|---|---|---|---|---|---|
| EPIC-XXX | FEAT-XXX | US-XXX | AC-XXX.1, AC-XXX.2 | TC-XXX | Alta | En progreso / Listo / Bloqueado |

> El campo "Estado" se mantiene actualizado en la herramienta operativa (Azure DevOps/Wrike); esta tabla se sincroniza en los cierres de fase, no en tiempo real, para evitar doble mantenimiento.
