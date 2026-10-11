---
name: theme-first
description: Gobierna los estilos en modo theme-first — cero valores de identidad visual quemados; todo sale de tokens/variables del tema. Antes de crear un token pasa un mini-pipeline (reusar, no duplicar, nombre semantico, preguntar ante casi-duplicado). Respeta exenciones y los estilos de vendor que el usuario no controla. TRIGGER — al escribir/modificar estilos, o el paso de UI de un increment.
---

# theme-first — gobernanza de estilos por tokens

Todo valor de **identidad visual** (color, gradiente, sombra, radio, fuente, espaciado, duracion, z-index, breakpoint, grosor) sale del **tema** (tokens/variables), nunca quemado en el componente. La fuente del tema esta en `bossdream.json > style.themeSource`. Agnostico: usa el sistema de tokens que ya use el repo.

## Alcance
- Solo estilos **AUTORADOS por el usuario**. Los estilos de **vendor** que el usuario no controla (`bossdream.json > style.vendorExempt`, ej. el estilo propio de un framework de UI) son intocables y no se juzgan.
- Mover/reordenar elementos NO es esto (eso es calidad UI/UX, dominio de `bossdream-design-auditor`).
- Gobierna lo **NUEVO/cambiado**. Consolidar el token-soup existente es una limpieza opt-in aparte, no forzada en cada cambio.

## Exenciones (no se tokenizan)
`0`, porcentajes, unidades de viewport (`vh`/`vw`), fracciones de grid (`fr`), y palabras clave (`auto`/`none`/`inherit`/`transparent`/`currentColor`...). Todo lo demas de identidad visual va al tema (incluidos `1px` y grosores, `line-height`, `opacity`, `font-weight`).

## Mini-pipeline de token (antes de crear un token)
1. **¿Amerita token?** Si el valor es exento, no se tokeniza.
2. **¿Ya existe?** Busca en el tema un token con el mismo valor o el mismo rol -> REUSAR, no crear.
3. **¿Casi-duplicado?** Si hay uno de rol igual con valor casi-igual (ej. 2rem vs 2.2rem) -> PARA y PREGUNTA al usuario si es intencional o una inconsistencia a consolidar. Nunca auto-crees el duplicado.
4. **¿Nombre semantico?** Por rol/escala (`--radius-md`), no por componente (`--radius-card`). Un mismo valor para otro objeto -> renombra a generico y reusa, no crees un segundo token.

## Reglas
- Cero valores de identidad quemados en estilos autorados.
- Ante ambiguedad de consolidacion, pregunta; no inventes tokens.
- El detector `style-check` valida despues (bloqueo duro sobre CSS/SCSS): un literal de identidad fuera de exenciones = falla.
- La deteccion sucia por tecnologia (estilos inline, CSS-in-JS, caminos C#<->JS<->CSS) la refuerzan los stack-packs, no el core.
