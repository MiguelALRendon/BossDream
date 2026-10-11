---
name: brainstorming
description: "Convierte una idea cruda en un diseno aprobado por el humano ANTES de escribir codigo. Preguntas socraticas de una en una, 2-3 enfoques con trade-offs, aprobacion del diseno seccion por seccion, y escribe plans/<feature>/design.md. Gate duro: no implementar ni hacer scaffold hasta que el humano apruebe. TRIGGER — inicio de una feature o cambio no trivial sin diseno acordado; antecede a /plan-new y al Plan Mode nativo."
---

# brainstorming — de idea a diseno aprobado

Gate previo a cualquier codigo. No implementes, no crees scaffolding, no escribas plan hasta que el humano apruebe el diseno.

## Proceso

1. **Explorar contexto**: archivos, docs y commits recientes relevantes (apoyate en `ctx`).
2. **Preguntas socraticas, de una en una**: proposito, restricciones, criterios de exito. Una pregunta por turno hasta que el objetivo real quede articulado — no asumas lo que el humano "quiso decir".
3. **Reto de sobriedad (Simplicity Ladder)**: antes de proponer, aplica la escalera del `bossdream` — ¿hace falta? ¿ya existe y se reusa? ¿lo resuelve stdlib/framework/dependencia? Descarta lo que no aporte.
4. **Proponer 2-3 enfoques** con trade-offs concretos y una recomendacion (usa `arch` si hay ≥5 componentes).
4.5. **Ofrecer mockup**: antes de generar o mostrar cualquier mockup visual, pregunta literalmente `"¿querés ver un prototipo de cómo se vería?"` y espera confirmación explícita antes de continuar — nunca lo muestra de una. Una vez confirmado:
   - Cuando el proyecto tiene un stack de UI ya identificado (ej. Razor Pages), el mockup se entrega como bloque de código embebido directamente en la respuesta (no como archivo separado) usando la sintaxis real de ese stack — verificable por la presencia de al menos un marcador específico de Razor (`@page`, `@model`, `@code`, o un tag helper como `asp-for`) en el bloque; un mockup que solo usa HTML/CSS genérico sin ningún marcador Razor es exactamente el caso que esta regla prohíbe.
   - El mockup se entrega como componente reutilizable, no como página completa armada de una sola pieza — verificable por 2 marcadores concretos: (a) el nombre de archivo del bloque lleva prefijo `_` (convención de partial view/componente Razor, ej. `_NotificationSettingsPanel.cshtml`), y (b) el bloque tiene un `@code` con al menos un parámetro de entrada (`[Parameter]` o equivalente) en vez de datos hardcodeados; un mockup que usa `@page` (página completa) o no declara ningún parámetro es exactamente el caso que esta regla prohíbe.
   - El nivel de detalle es proporcional a la complejidad de lo pedido — verificable por un umbral concreto de líneas de código Razor en el bloque: un pedido de "elemento simple" (ej. un botón) produce un bloque de ≤8 líneas; un pedido de "flujo/panel completo" produce un bloque de >8 líneas.
5. **Presentar el diseno por secciones**, ordenadas por complejidad (de 1 frase a ≤300 palabras). **Pedir aprobacion tras cada seccion**, no un OK global.
6. **Escribir el design doc** en `plans/<feature>/design.md` (con fecha en el frontmatter) y sugerir commitearlo.
7. **Self-review del diseno**: escanea placeholders, contradicciones, ambiguedad y scope antes de cerrar.
8. **Transicion**: solo con el diseno aprobado → `/plan-new <feature>` (spec/plan/tasks) y luego el plan.

## Reglas

- **No codigo antes de aprobacion.** Este es el punto que Superpowers acierta y que el framework necesitaba. El mockup del paso 4.5 no es una excepcion: es un bloque ilustrativo embebido en la respuesta (nunca un archivo escrito al repo) y solo aparece tras confirmacion explicita — sigue siendo diseno, no implementacion real.
- Combina dos ejes: completitud (que no falte nada) **y** sobriedad (que no sobre nada). No sacrifiques uno por el otro.
- Antecede al Plan Mode nativo de Claude Code: brainstorming acuerda el QUE/diseno; Plan Mode o `/plan-new` estructuran el COMO.
