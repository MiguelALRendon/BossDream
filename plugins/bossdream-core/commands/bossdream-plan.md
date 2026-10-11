---
name: bossdream-plan
description: "De una historia cruda del usuario a un plan ejecutable por increments. Investiga (codigo + web), verifica impacto cross-flow, propone 2-3 opciones y construye el plan INCREMENTALMENTE: cada increment pasa su revision de diseno antes de escribirse al MD. Escala la ceremonia al tamano (trivial->directo, task->ligero, grande->deep-plan). TRIGGER — el usuario describe QUE quiere lograr (una historia/necesidad), no una solucion ya hecha. NOTA: se llama bossdream-plan (NO plan) para no colisionar con el Plan Mode NATIVO de Claude Code."
disable-model-invocation: true
arguments:
  - name: historia
    description: "la necesidad/historia del usuario, en sus palabras"
---

# /bossdream-plan — de historia cruda a plan por increments

Produce `plans/<feature>/{spec.md, design.md, plan.md}`. El corazon: **cada increment pasa su revision de diseno ANTES de entrar al `plan.md`**.

> **El comando es `/bossdream-plan`, NO `/plan`.** `/plan` es el Plan Mode NATIVO de Claude Code y NO ejecuta esta gobernanza: su aprobacion de ExitPlanMode dice "you can now start coding" y eso NO es autorizacion dentro de BossDream. Usa siempre `/bossdream-plan`.

## FRONTERA DURA (mode-lock) — leelo primero
`/bossdream-plan` corre en **modo `plan` (NO-editable)**. El hook `readiness` fija `.claude/.work-mode=plan` y el `plan-lock` **NIEGA toda edicion de codigo** (extensiones de `bossdream.json > codeExtensions`, pobladas por el stack-pack instalado) mientras dure. **Tu unico entregable es documentacion** (`.md`/`.feature`): `spec.md`, `design.md`, `plan.md`, ADRs.

- **NUNCA implementes.** No escribas codigo, no despaches subagentes de implementacion (bossdream-coder, etc.), no corras builds "para probar".
- **NUNCA cambies el modo por tu cuenta.** El plan termina cuando el `plan.md` esta completo. Ahi **PARAS**.
- Al cerrar, **INDICA al usuario que ejecute `/bossdream-implement`** para arrancar la ejecucion. Solo el usuario lo corre; al hacerlo, el hook cambia el modo automaticamente. Tu nunca lo disparas ni cambias `.work-mode` a mano.
- Si crees que hace falta tocar codigo para validar algo: **dilo en el plan como paso pendiente**, no lo hagas.

### Cambios ad-hoc mientras el plan sigue activo (no lo confundas con ejecutar el plan)
Si el usuario pide, en medio de la sesion de planeacion, algo **no relacionado con el plan que se esta construyendo** (ej. "cambia este icono", "corrige este typo"), **`/bossdream-implement` NO es el camino** — eso ejecuta el `plan.md` completo, increment por increment, y esto no es un increment del plan. El modo `plan` tampoco se cambia solo porque el pedido sea chico. Triage correcto (misma escalera YAGNI de la seccion 0, aplicada a la peticion ad-hoc en vez de al plan):
- **Pesado / no trivial** (toca >1 archivo, decision de arquitectura, ambiguedad) → no es ad-hoc de verdad: es una feature aparte. Sugiere `/bossdream-plan` para ella cuando este plan cierre.
- **Menor pero real, no relacionado con el plan activo** (el caso del icono) → **indica al usuario `/bossdream-mode chore`** (o `spike`/`explore`/`bugfix` segun aplique). Es un comando de una palabra, no ejecuta el plan ni sus increments; el mode-lock lo deja editar de inmediato, y el pipeline local del Stop hook igual corre antes de "done" (build/formato/pruebas) — no es saltarse el gate, es saltarse la ceremonia de increment que no aplica aqui.
- **Trivial e informativo** (no toca codigo) → responde directo, sin gate de ningun tipo (ya lo cubre el SKIP de la skill `bossdream`).
Nunca hagas la edicion tu mismo estando en modo `plan`: siempre indica el comando que le toca al usuario segun el tier.

## 0. Triage (escalera YAGNI)
- **Trivial** (1 linea / cambio obvio) → NO planees; dilo y hazlo directo.
- **Una task** (un importador, un campo) → plan ligero: 1 increment, pasos, sin research web.
- **Grande / reestructura** → deep-plan completo (todo lo de abajo).

## 1. Clasifica
`modify-flow` (modifica un flujo existente) | `add-to-flow` (agrega, posible reestructura) | `new` (nada existe). Define cuanto analisis de codigo hace falta.

## 2. Investiga (delega; llena el research-log)
- **Codigo**: cascada `ctx` → codebase-memory (grafo) → Serena/LSP (simbolos) → Grep → Read acotado.
- **Externo**: context7 (docs de stack), fetch (URLs), Explore + WebSearch/WebFetch (busqueda amplia/multi-fuente).
- Registra cada hallazgo en el research-log del `plan.md`: `pregunta | tool | hallazgo | como informo`.

**Pipeline de investigacion — autorevision obligatoria de CADA hallazgo antes de registrarlo, no un tramite opcional:**
- [ ] Uso el contexto ya disponible (repo/conversacion) antes de buscar mas.
- [ ] La pregunta investigada es la pregunta REAL, no una generica derivada.
- [ ] Sintesis, no solo datos crudos — conecta los hallazgos entre si, no los lista sin interpretar.
- [ ] Cada afirmacion cita `archivo:linea` (repo) o URL+fecha (web) — nunca una frase sin fuente verificable.
- [ ] Detecta y reporta contradicciones entre fuentes (codigo vs doc vs lo dicho antes en la conversacion).
- [ ] Si es investigacion web: la fuente es vigente para la version/contexto real del proyecto, no una version distinta sin avisar.
- [ ] Responde exactamente lo preguntado — nada tangencial presentado como si respondiera la pregunta.

## 3. Impacto cross-flow
`codebase-memory.trace_path`/`query_graph`: ¿tocar esto rompe otros flujos? Registra en la tabla de impacto; si hay choque, propon mitigacion o replantea antes de seguir.

## 3.1 Deuda tecnica (informativa, NO bloqueante)
Corre el skill `tech-debt` sobre los flujos/areas que el plan va a TOCAR e incluye sus hallazgos como seccion **informativa** del `plan.md`. Es enforcement **NO obligatorio**: surface la deuda relevante para que el usuario decida si la paga como parte del plan (agregando increments) o la ignora. **Nunca bloquea la planeacion.**

## 4. Propon (cuestiona, no aceptes a ciegas)
- **brainstorming** socratico: preguntas de una en una hasta articular el objetivo real (no el asumido).
- **arch**: 2-3 opciones con trade-offs concretos (respaldadas por research interno + web) + recomendacion.
- **Ponytail**: reta necesidad/tamano de CADA idea, incluidas las del usuario. Aprobacion del diseno por secciones → `design.md`.

## 5. Construye el plan por increments — INCREMENTAL
Por cada increment, en orden:
1. Redacta: objetivo (entregable), que criterios de `spec.md` cubre, y sus **PASOS** (codigo y no-codigo; skill/mcp/tool por paso). **El penultimo paso SIEMPRE es "pruebas unitarias"** (generar/actualizar con `test-gen`, solo codigo de logica, respeta exenciones) y **el ultimo SIEMPRE es doc-check** (via `docs-rewrite`). Cada increment lleva ademas el campo **`Verificacion funcional:`**: `navegador` (flujo feliz y validaciones rutinarias con Playwright), `datos` (confirmar lo persistido con `dbhub`, solo lectura) o `no aplica: <justificacion>`; nunca vacio.
   - Tras redactar los pasos de ESE increment, despacha el agente `bossdream-document-explorer` pasandole esos pasos recien redactados. Devuelve un veredicto `{objetos, skills_encontradas, candidatos_sin_skill}`.
   - Por cada entrada de `skills_encontradas`: se enlaza directo en `conexiones:` (ver abajo), citando la seccion/proceso concreto que reporto el explorer.
   - Por cada entrada de `candidatos_sin_skill`: invoca la skill `tech-debt` sobre el area/flujo relevante para confirmar si es duplicacion real (no solo la sospecha del explorer).
     - Si `tech-debt` confirma duplicacion real: invoca la skill `brainstorming`, reusando sus pasos 1-2-3-5-7 (explorar contexto, preguntas socraticas 1-a-1, Simplicity Ladder, presentar por secciones con aprobacion — esto ES el "preview" que se le muestra al usuario antes de escribir nada, y el usuario puede corregir en esa aprobacion por seccion —, self-review), adaptando el paso 6 de `brainstorming` para que en vez de escribir `plans/<feature>/design.md` escriba/actualice `plugins/bossdream-core/skills/<nombre-nuevo>/SKILL.md`, y sin el paso 8 (no aplica transicion a `/plan-new`). Solo se escribe el archivo tras aprobacion explicita del usuario.
     - Si `tech-debt` NO confirma duplicacion real (falso positivo del explorer): se descarta, el objeto queda sin skill.
   - **`conexiones:` es un campo obligatorio del increment, nunca se omite**: lista las skills enlazadas o creadas por el proceso anterior, o el texto literal `"sin skill aplicable"` si `candidatos_sin_skill` quedo vacio tras descartar falsos positivos.
2. Define el **pipeline del increment** (que stages/tests lo validan en ejecucion).
3. **Revision de diseno del increment (checklist):**
   - [ ] los pasos cubren el objetivo del increment
   - [ ] sin placeholders ni vaguedad ("TBD", "manejar errores", "similar a...")
   - [ ] no choca con otros flujos (cross-flow verificado)
   - [ ] incluye el paso doc-check
   - [ ] dependencias entre pasos/increments coherentes
   - [ ] pipeline del increment definido y verificable
   - [ ] tiene `Verificacion funcional:` (navegador / datos / no aplica con justificacion)
   - [ ] **cada paso trae su FUENTE** (`archivo:linea` / query / doc) **y su PORQUE**
   - [ ] **cada decision lista la opcion elegida Y las descartadas + razon**
   - [ ] **toda afirmacion ancla a evidencia real**; si no se pudo verificar, se marca `supuesto — verificar` (nunca se da por hecho)
   - [ ] conexiones: cada skill enlazada/creada cita la seccion/proceso concreto del SKILL.md que justifica el enlace (no un match ciego por nombre)
   Increment grande/riesgoso → escala esta revision a un **subagente revisor adversarial**.
   > Un plan sourced + justificado (cada linea trazable a su fuente y su porque, con alternativas descartadas) es el estandar: mas efectivo que un plan que solo "se ve bien", porque es auditable y retable.
4. Si pasa → **agregalo al `plan.md`**. Si no → corrige y re-revisa. **Nunca escribas al MD un increment no revisado.**
Siguiente increment.
Al final agrega SIEMPRE el **QA Increment** como ultimo increment (skill `qa-increment`; usa el modo de `bossdream.json > qa.mode`). El QA profundo vive ahi; la `Verificacion funcional:` de cada increment es la comprobacion rapida del flujo.

## 6. Cierre
- `/adr-new` para decisiones significativas.
- Despacha `bossdream-completeness-auditor` sobre `spec.md`/`plan.md` completos de la feature (paso adicional, no reemplaza `/adr-new`, que sigue corriendo igual). Segun el veredicto:
  - `VERDICT: pass | sin sistemas externos detectados` → el cierre sigue exactamente igual que hoy, sin cambios.
  - Con hallazgos (`estado: bloqueante` o `estado: pregunta_al_usuario`): presentalos TODOS en una sola tanda batcheada (mismo patron de `validation-run` SKILL.md paso 7 — una pregunta/hallazgo concreto por linea, no un ensayo) y NO anuncies "Plan completo" hasta que el usuario los resuelva (agregando increments/criterios al plan si aplica, o confirmando explicitamente que no aplican).
- El `plan.md` queda listo. **Cierra INDICANDO al usuario:** "Plan completo. Para ejecutarlo, corre `/bossdream-implement`." Cada increment ya paso su revision de diseno; el usuario decide cuando arrancar.

## Reglas
- Nunca inventes: todo hallazgo ancla a codigo o a research citado.
- Escala al tamano: no hagas deep-plan de un one-liner.
- El plan MD es el producto de esta fase; se versiona en git.
