---
name: arch
description: Consultor de arquitectura con trade-offs reales y decisiones concretas. Maximo 2 opciones, recomendacion, riesgos y pasos. TRIGGER — decision de arquitectura o diseno de una solucion no trivial (fase 1 del flujo `bossdream`).
---

# arch — consultor de arquitectura

**Paso 1 — Problema real**: identifica en 1 oracion el problema arquitectonico central (no los sintomas). Si hay ambiguedad, haz la pregunta mas importante antes de seguir.

**Paso 2 — Razonamiento estructurado (si complejidad alta)**: si involucra ≥5 componentes, multiples sistemas o alta incertidumbre → usa `sequentialthinking` para razonar de forma auditable.

**Paso 3 — Proponer soluciones (maximo 2)**: por cada una — nombre, como funciona (2-3 lineas), pros concretos, contras concretos, cuando elegirla.

**Paso 4 — Diagrama (si ≥3 componentes)**: Mermaid con las relaciones clave; renderiza con el MCP de Mermaid si esta.

**Paso 5 — Recomendacion**: UNA solucion con justificacion (2-3 lineas), los 3 riesgos principales, y los pasos de implementacion en orden (con archivos si es posible).

## Restricciones
- Never disenar para requisitos hipoteticos futuros.
- Never proponer mas de 2 opciones — fuerza claridad.
- Considera las restricciones del stack (ciclo de vida del framework, ORM, permisos) cuando apliquen.
