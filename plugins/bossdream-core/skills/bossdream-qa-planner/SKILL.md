---
name: bossdream-qa-planner
description: Invoca al agente bossdream-qa-planner para emitir un veredicto ACCEPTED/REJECTED sobre la calidad de pruebas de una implementacion, incluso con tests/coverage/mutation en verde. TRIGGER — el usuario pide una autoridad de QA que revise si una implementacion esta realmente probada, no solo si los tests pasan.
disable-model-invocation: true
arguments:
  - name: run
    description: "sin valor — despacha el agente bossdream-qa-planner sobre los artefactos disponibles del proyecto actual"
---

# bossdream-qa-planner — QA Manager

Autoridad de QA que puede rechazar una implementacion aunque `tests: green`, `coverage` y `mutation` esten altos, si detecta comportamiento/reglas/transiciones sin evidencia real. El juicio requiere razonamiento sobre comportamiento — no es un gate determinista, por eso es un agente (`agents/bossdream-qa-planner.md`, `model: sonnet`), no un script.

## Como invocarlo

Quien invoca este skill despacha el agente `bossdream-qa-planner` (Task/Agent tool) pasandole, como archivos a leer, los artefactos disponibles del proyecto bajo revision:

1. **Test Inventory** — `.bossdream-project/test-inventory.json` si existe (formato de 9 campos documentado con ejemplo inline en `agents/bossdream-qa-planner.md` — el generador automatico `agents/bossdream-qa-gatekeeper.md` aun no existe; si el archivo no esta, el agente lo trata como evidencia insuficiente, no como excusa para aceptar).
2. **Resultado de `scripts/test-checks.ps1`** — correrlo primero (`pwsh -File scripts/test-checks.ps1 -ProjectDir <ruta>`) y pasar su salida JSON al agente.
3. **Hallazgos de Test Critic** — `agents/bossdream-qa-auditor.md`. Opcional: si no hay artefacto de Test Critic, se omite sin bloquear la invocacion.

El agente nunca recibe el proyecto completo — solo esos 2-3 artefactos.

## Reporte

Veredicto textual del agente, formato exacto: primera linea `QA VERDICT: ACCEPTED|REJECTED`, una linea por razon aplicable con etiqueta (`Missing validation coverage:` / `Missing flow transition:` / `Mutation survived:` / `Evidence insufficient:`) + detalle concreto. Ver `agents/bossdream-qa-planner.md` para el contrato completo y ejemplos.

Quien invoco este skill usa ese veredicto tal cual — no se reinterpreta ni se suaviza un `REJECTED`.

## Pendiente

- `--flow-model` (matriz de cobertura de flujos).
- Consumo automatico de hallazgos de Test Critic.
- Integracion como `quality_approval` real dentro de `scripts/test-checks.ps1` (hoy stub `pending`).
