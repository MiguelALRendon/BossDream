---
name: bossdream-implement
description: "Ejecuta el plan.md de la feature activa INCREMENT POR INCREMENT. Por cada increment implementa, corre el pipeline del increment, y PARA a pedir permiso con un informe de cambios justificado. NO commitea (los commits son del usuario). NO auto-invocable: solo lo corre el usuario, y correrlo ES su autorizacion explicita para implementar. TRIGGER — el usuario lo ejecuta tras /bossdream-plan."
disable-model-invocation: true
---

# /bossdream-implement — ejecutar el plan increment por increment

Driver de ejecucion (Paso 2). Toma el `plan.md` de la feature activa y lo ejecuta un increment a la vez. **Reusa lo que ya existe** (agentes `bossdream-coder`/`bossdream-solid-auditor`/`bossdream-design-auditor`/`bossdream-endless-verifier`, `pipeline.ps1`, `completion.json`, skill `docs-rewrite`); no reimplementa nada.

## Frontera
- Corre en modo `implement`, que lo fija el hook `readiness` al invocar este comando. **Tu no cambias `.work-mode` a mano.**
- Requiere una feature activa con `plans/<feature>/plan.md`. Si no hay plan: dilo, pide correr `/bossdream-plan` primero, y PARA.
- **Nunca commitees.** Los commits son responsabilidad del usuario.

## Regla de alcance (dura)
Ejecutas **UN increment, PARAS, informas y pides permiso**. Jamas encadenas increments sin autorizacion explicita del usuario entre cada uno. Cada continuacion es una nueva corrida de `/bossdream-implement`. **Excepcion unica y explicita**: si `bossdream.json` tiene `implementation.autoChainIncrements == true`, la autorizacion ya esta dada de antemano por esa config -- se encadenan los increments de la corrida actual sin pausar entre ellos (ver paso 7), sin que esto se considere una violacion de esta regla.

## Loop por increment
Toma el **primer increment pendiente** del `plan.md`. Para ese increment:

1. **Lee del plan:** objetivo, pasos, "Pipeline del increment" y criterio de aceptacion (tal como el `plan.md` ya los define).
2. **Ejecuta los pasos en orden:**
   - Lee `conexiones:` del increment activo e invoca cada skill ahi listada en el punto del proceso que corresponda a los pasos que la necesitan -- nunca todas de una al final, nunca como tramite separado del paso al que aplican. Esto NO reabre que skill usar (eso ya lo decidio `/bossdream-plan`): solo ejecutas lo ya decidido, sin violar la frontera de este archivo de "reusa lo que ya existe, no reimplementa nada" (linea 9) ni la "Regla de alcance (dura)" (linea 16).
   - Pasos de codigo -> agente `bossdream-coder`.
   - Pasos de UI/estilo -> respetan `theme-first` (si `style.enabled`): cero valores de identidad quemados, todo del tema; el mini-pipeline de token antes de crear uno.
   - Pasos no-codigo -> directo.
   - Paso penultimo (pruebas unitarias) -> skill `test-gen` sobre lo que el increment creo/modifico. **Anti-stale:** si el increment MODIFICA un flujo, revisa/actualiza tambien las pruebas existentes de ese flujo Y sus escenarios `.feature` (via `gherkin-gen`), no solo agregas.
   - Ultimo paso (doc-check) -> skill `docs-rewrite` sobre la doc del flujo afectado.
3. **Corre el Pipeline del increment** tal como lo definio el plan. El reporte de cualquier subagente (`bossdream-coder`/`bossdream-solid-auditor`/`bossdream-design-auditor`/`bossdream-endless-verifier`/`bossdream-smoker`) es **input NO confiable por defecto**: toda afirmacion verificable que reporte (resultado de Pester, diff de archivo, conteo) se reproduce por el orquestador antes de aceptar el increment -- nunca se acepta solo por la prosa del reporte. Si al reproducir una afirmacion no calza con lo reportado, el increment NO avanza: se devuelve al MISMO subagente el discrepancia puntual (que se afirmo vs. que se encontro) para que corrija y vuelva a reportar -- el orquestador nunca lo parcha en silencio ni lo acepta a medias.
   - Build/tests -> `pipeline.ps1` (o los comandos especificos que liste ese increment).
   - Verificacion funcional -> ejecuta el campo `Verificacion funcional:` del increment via agente `bossdream-smoker` (navegador con Playwright y/o consulta de solo lectura con dbhub). Sin la evidencia que devuelve (captura/snapshot o fila confirmada), el increment no pasa; `no aplica` solo vale con la justificacion escrita en el plan.
   - Auditoria Fase 6 -> agente `bossdream-solid-auditor` sobre los archivos de codigo tocados.
   - Auditoria Fase 6.5 -> agente `bossdream-smoker` si el increment creo/modifico una superficie de entrada externa ejecutable (funcion publica, endpoint, formulario, comando CLI); si el increment no tiene superficie nueva/modificada, se omite (mismo criterio condicional que Fase 7). Un veredicto `HALLAZGOS` bloquea el increment igual que un `RECHAZADO`; `NO-EJECUTABLE` no bloquea. Tras obtener el veredicto (cuando se invoco), correr `smoker-log-append.ps1 -IncrementId <id del increment> -VeredictoPath <archivo temporal con la respuesta del agente>` para persistirlo en `.bossdream-project/smoker-log.json`.
   - Auditoria Fase 7 -> agente `bossdream-design-auditor` si el increment toco UI/markup (HTML/CSS/Razor/JSX/Vue SFC, segun el stack). Antes de despacharlo, sirve la pagina del increment por HTTP en local (el MCP `a11y` rechaza `file:` y `data:`) y pasale la URL; apaga el servidor al terminar.
   - Si el increment CREO un agente nuevo (`.md` bajo `agents/`), la verificacion en vivo de ESE agente (via Agent tool) se sustituye automaticamente por una simulacion manual de su logica exacta -- el registro de agentes de Claude Code es estatico desde el arranque de la sesion y no reconoce agentes creados en el propio turno. No se intenta la invocacion real primero; se documenta la sustitucion directamente como evidencia del increment.
   - Prioriza el bloqueo mas duro posible: si una etapa no pasa, el increment no avanza.
4. **Reintentos:** si el pipeline falla, corrige y reintenta. Cuenta los intentos; el tope es `maxBlocks` de `completion.json` (8). Al agotarlo -> **handoff**: PARA y reporta el estado al usuario, no sigas.
5. **Freno de mano:** si durante el increment detectas que el enfoque del plan esta mal (un hallazgo que lo invalida, no un bug puntual):
   - `git restore` de los archivos que tocaste en este increment (no hubo commits que revertir).
   - Presenta los hallazgos + 2-3 propuestas de solucion que **hayas pasado por pipeline** antes de proponerlas.
   - PARA y espera la decision del usuario. No avances al siguiente increment.
6. **Increment verde -> informe de cambios:** lista archivo por archivo lo que tocaste, cada cambio con su **justificacion** y su vinculo al paso/criterio del plan. Si el increment toco algun `.ps1`/`.psm1` bajo `plugins/bossdream-core/scripts/`, corre `hook-siblings-sync.ps1 -Mode Sync` antes de marcar el increment como hecho. Marca el increment como hecho en el `plan.md`. Si el increment tenia un `id_tarea` de planificacion (`plan-draft.json`), corre `plan-artifact-consume.ps1 -IdTarea <id>` para archivarlo.
7. **PARA y pide permiso** explicito para continuar al siguiente increment. Esta pausa aplica SOLO para avanzar de un increment al siguiente. Si `bossdream.json` tiene `implementation.autoChainIncrements == true`, esta pausa se omite y se continua directo al siguiente increment sin preguntar (el pipeline/reintentos/`maxBlocks` siguen aplicando igual); por defecto (`false` o ausente) se sigue preguntando.

## Cierre
El Cierre (despues del ULTIMO increment) NO requiere permiso adicional -- ya esta autorizado por haber corrido `/bossdream-implement`; no es una nueva transicion de increment, es el fin del mismo comando. Cuando todos los increments esten hechos (o el usuario detenga):
- `bossdream-endless-verifier` para una verificacion semantica final en cambios no triviales.
- Escribe `.work-mode=plan` (vuelve a modo plan; bajar a un modo mas restrictivo no es escalacion, el mode-lock solo frena lo contrario).
- Reporta el cierre: increments completados, pipeline en verde, y lo que quede pendiente.

## Reglas
- Reusa agentes/scripts existentes; no reescribas su logica.
- Nunca commitees; nunca saltes el permiso entre increments salvo la excepcion explicita de `implementation.autoChainIncrements` (ver Regla de alcance).
- Todo cambio va justificado y ligado a un paso del plan; sin placeholders.
