---
name: flow-test-gen
description: Genera el catalogo combinatorio de Pruebas de Flujo (workflow/business process testing, saga pattern testing cuando hay rollback) para el QA Increment del proyecto activo, usando all-transitions/round-trip coverage (ISTQB) como criterio explicito. Presenta cada caso al usuario uno por uno para aprobar/corregir/rechazar, y una vez aprobados escribe las pruebas de integracion/E2E reales con el framework del stack-pack instalado. TRIGGER — /bossdream-implement, en el penultimo paso del QA Increment (mismo lugar donde test-gen se invoca en cualquier increment normal).
arguments:
  - name: proyecto
    description: "slug del proyecto activo"
---

# flow-test-gen — catalogo combinatorio de Pruebas de Flujo

Contraparte de `test-gen` (que cubre unidades de codigo) pero para **flujos de negocio multi-paso** — terminologia correcta segun ISTQB/Fowler/IEEE/NIST: *workflow/business process testing*, mezcla de integration + system testing, y **saga pattern testing** cuando hay rollback/compensacion.

## Proceso

1. **Modela el flujo**: lee `requirements.md` (las US relacionadas a la Feature en curso) + `tests/test-approach.md` (ya validado por `/bossdream-validate`) y extrae la secuencia de pasos/estados del flujo de negocio (ej. "generar factura → timbrar → enviar → registrar pago"), mas cualquier transicion de rollback/compensacion que el negocio ya haya descrito.
2. **Genera el catalogo** usando *all-transitions coverage* (cubrir cada paso→siguiente del flujo lineal, mas cada rollback declarado) y *round-trip testing* (ida y vuelta inmediata sobre el mismo estado) como criterios explicitos — no "cobertura razonable a juicio". Incluye, cuando aplique: saltos de paso, limites de tamano de input, duplicidad/reintentos, timeouts/fallos a medio flujo, rollback/compensacion.
3. **Autoverifica el catalogo antes de presentarlo**: escribe la definicion del flujo y el catalogo generado a JSON temporal, y corre `scripts/flow-coverage-check.ps1 -FlowDefinitionPath <bossdream.json> -CatalogPath <catalogo.json>`. Si `status: "blocked"` (faltan transiciones), completa el catalogo con los casos que falten y vuelve a correr el check antes de continuar — **nunca presentes al usuario un catalogo con cobertura incompleta sin decirlo**.
4. **Presenta cada caso uno por uno** al usuario para aprobar/corregir/rechazar — mismo patron que `/bossdream-testcase` (nunca en lote, nunca asumido como aprobado).
5. **Una vez aprobados**: escribe las pruebas de integracion/E2E reales usando el framework que ya trae el stack-pack instalado (Reqnroll/Playwright para .NET, Cucumber/Playwright para Node) — esto activa las etapas 7 (Integracion) y 9 (E2E) del `pipeline.json` del proyecto consumidor, que hoy vienen `enabled:false` hasta configurarse.
6. **Nota final obligatoria**: siempre agrega, como ultimo punto del reporte, una nota pidiendo validacion humana/UAT explicita sobre los casos que dependan de juicio de negocio ambiguo (*test oracle problem*, IEEE) — nunca se asume que el catalogo automatizado cubre el 100% del criterio de exito.

## Integracion con `/bossdream-implement` (decision 8 — sin modificar `bossdream-implement.md`)

El QA Increment vive en su propio `plans/<slug>-qa-increment/plan.md`, tratado como la ultima Feature del rollup `roadmap.md`. Esta skill se invoca en el **penultimo paso** de ese increment — exactamente el mismo lugar donde `test-gen` ya se invoca en cualquier increment normal — y el ultimo paso sigue siendo doc-check via `docs-rewrite`, igual que todos los demas increments. `/bossdream-implement` no necesita saber que este increment es "especial": lo ejecuta igual que cualquier otro.

## Alcance por clasificacion (decision 5)

- **Simple**: checklist de smoke test — no se genera catalogo combinatorio.
- **Medio**: catalogo combinatorio limitado a los flujos criticos declarados en `tests/test-approach.md`.
- **Complejo**: catalogo completo (todas las transiciones) + regresion + integracion + revision de seguridad si toca datos sensibles.

## Reglas

- **No se agrega ningun agente para esta skill** — generar el catalogo es razonamiento sobre criterios explicitos, no auditoria independiente; corre en el hilo del increment, igual que `test-gen` hoy.
- Nunca se de por cubierta una transicion sin que algun caso del catalogo la ejercite explicitamente — usa `flow-coverage-check.ps1`, no "a ojo".
- No modifica los comandos/scripts core del motor del Delivery Cycle (`bossdream-plan.md`, `bossdream-implement.md`).
