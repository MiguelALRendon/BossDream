---
name: test-gen
description: Genera pruebas unitarias para una funcion, un flujo o una funcionalidad, pensadas COMO USUARIO (no como programador) — adversarial primero, happy path al final. Cada prueba pasa un pipeline de calidad antes de crearse. Respeta las exenciones (el codigo trivial no se prueba). TRIGGER — el paso "pruebas unitarias" de un increment, o cuando el usuario pide generar/actualizar pruebas de una funcion o flujo.
---

# test-gen — generacion de pruebas con filosofia adversarial

Genera pruebas unitarias del **codigo de logica/negocio** (no de la presentacion/UI). Es agnostico: sigue el framework de pruebas y la convencion que YA usa el repo. **Antes de escribir, lee pruebas existentes del proyecto y copia su estilo.** El proyecto de pruebas y las exenciones se leen de `bossdream.json > testing`.

## Que se prueba y que no
- **Requerido:** procesos, funciones con ramas/calculos/validaciones/transformaciones, y flujos.
- **Exento** (`bossdream.json > testing.exemptions`): accesores simples, contenedores de datos puros, constructores triviales, catalogos/altas repetidas sin logica, mapeos 1:1, codigo autogenerado, cableado/configuracion, presentacion/UI.
- **Alcance:** lo que el increment CREA o MODIFICA (una funcion, ampliable hasta un flujo completo), no el proyecto entero.

## Filosofia: piensa como USUARIO, no como programador
Enumera primero como se ROMPE, no como funciona:
1. Casos borde y limites (0, 1, maximo, minimo, vacio, nulo).
2. Entradas invalidas o inesperadas.
3. Errores y estados de fallo.
4. Concurrencia / orden / repeticion, si aplica.
5. **El happy path va AL FINAL** — es lo ultimo que se prueba.

## Pipeline del test (cada prueba pasa esto ANTES de crearse)
1. No se repite dentro del grupo de pruebas de esa funcion.
2. Se declara de cuantos casos previene (su valor = cuantas fallas distintas cubre).
3. Exactamente UN happy-path por grupo de esa funcion, salvo que el usuario declare varios.
4. Debe poder fallar: si se rompe lo que prueba, la prueba falla. Nada de "siempre verde".
5. Nombra el caso adverso que cubre.
6. Prueba UNA sola cosa (un solo motivo de fallo).
7. Independiente: no depende del orden ni de estado que dejo otra prueba.
8. Determinista: mismo resultado siempre (sin azar, tiempo o red sin controlar).
9. El grupo cubre adversarial primero, happy path al final.
10. Asercion con sentido: revisa el valor/comportamiento esperado, no solo "no truena".
11. Nombre por escenario: el nombre dice el caso, para que un fallo se explique solo.

Una prueba que no pasa el pipeline no se crea; se corrige o se descarta.

## Salida
- Pruebas en el proyecto de pruebas del repo (`bossdream.json > testing.project`), con la convencion existente.
- Por cada grupo de funcion: la lista de casos adversos cubiertos + el unico happy path.
- Stryker valida despues la calidad: si un sabotaje al codigo no lo caza ninguna prueba, falta una prueba — se vuelve aqui a agregarla.

## Reglas
- No inventes comportamiento: prueba lo que la funcion/flujo hace segun su codigo y los criterios de la spec.
- No pruebes lo exento.
- Ningun grupo con mas de un happy path sin que el usuario lo pida.
