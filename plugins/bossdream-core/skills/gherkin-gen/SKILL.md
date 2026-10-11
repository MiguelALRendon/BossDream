---
name: gherkin-gen
description: Genera los escenarios Gherkin (.feature) de una feature a partir de los criterios de aceptacion del spec.md. Adversarial primero, UN happy path al final, cada escenario con @cubre. Si el criterio es ambiguo o no define todo el camino, PREGUNTA en vez de inventar. TRIGGER — lo invoca plan-new, o cuando se agrega/modifica un flujo y hay que crear/actualizar sus escenarios.
---

# gherkin-gen — escenarios de aceptacion desde la spec

Convierte los criterios de aceptacion del `spec.md` en escenarios Gherkin legibles: **documentacion viva del comportamiento** y base de la prueba de aceptacion. Agnostico: usa el idioma y estilo Gherkin que ya use el repo (Dado/Cuando/Entonces o Given/When/Then).

## Regla dura: no inventes, PREGUNTA
Si un criterio es **ambiguo** o **no define todo el camino** (falta una precondicion, un dato, un resultado esperado o un caso de error), **pregunta al usuario las dudas concretas antes de escribir el escenario.** Nunca rellenes el hueco a criterio propio.

## Como piensa: como USUARIO, no como programador
Enumera primero como se ROMPE el flujo, luego como funciona:
1. Casos borde y limites del flujo.
2. Entradas invalidas / precondiciones no cumplidas.
3. Errores y caminos de fallo.
4. AL FINAL: el camino feliz.

## Marcadores (por defecto)
- `@happy` — EL unico escenario de camino feliz del flujo (uno por `.feature`, salvo que el usuario declare varios).
- `@borde` / `@error` — escenarios adversariales.
- `@cubre:<flujo o funcion>` — en CADA escenario, enlaza con lo que lo respalda (el puente con las pruebas unitarias).

## Salida
- Un `.feature` por flujo: `Feature:` + escenarios con pasos `Dado/Cuando/Entonces`.
- Cada escenario con su marcador y su `@cubre`.
- Un solo `@happy`.

## Reglas
- Deriva de los criterios del `spec.md`; ante hueco, pregunta.
- Adversarial primero, happy al final.
- Estos escenarios son documentacion SIEMPRE; ejecutarlos como prueba (etapa `bdd`) es opt-in (`bossdream.json > testing.bdd`).
- El chequeo `gherkin-check` valida despues: un solo `@happy`, `@cubre` en cada escenario, estructura de pasos presente.
