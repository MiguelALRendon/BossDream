---
name: plan-checks
description: Corre el Plan Checks (10 gates que demuestran que un plan-draft.json realmente entiende el problema antes de aprobarse). TRIGGER — el usuario pide validar un plan antes de aprobarlo, o preguntar el estado de un gate concreto del Plan Checks.
disable-model-invocation: true
arguments:
  - name: plan
    description: "ruta a plan-draft.json a validar"
  - name: gate
    description: "uno de los 10 gates: evidence | change-surface | existing-solution | alternative-pressure | blast-radius | testability | minimality | executability | intent-integrity | contradiction"
---

# plan-checks — Plan Checks

Cadena de 10 gates deterministas + semanticos que un `plan-draft.json` debe atravesar antes de aprobarse.

## 8 gates deterministas (este skill, `scripts/plan-checks.ps1`)

`evidence`, `change-surface`, `existing-solution`, `alternative-pressure`, `blast-radius`, `testability`, `minimality`, `executability` — validacion estructural pura (campos presentes, no vacios, shape correcto). Cada uno produce la salida JSON exacta propia de cada gate, mas `status: "pass"|"blocked"` y, si `blocked`, `razon` con el detalle de lo que falta.

Correr a mano:

```
pwsh -File scripts/plan-checks.ps1 -PlanPath <ruta a plan-draft.json> -Gate <valor>
```

Exit code 0 si `status: "pass"`, 1 si `status: "blocked"`.

## 2 gates semanticos (`intent-integrity`, `contradiction`)

Requieren juicio (¿es necesidad o solucion disfrazada?; ¿el plan se contradice?), no verificacion estructural. `scripts/plan-checks.ps1 -Gate intent-integrity` o `-Gate contradiction` **no evalua** — devuelve directo:

```
{ "status": "requires-agent", "agente": "bossdream-planner-auditor", "instruccion": "Invocar el agente bossdream-planner-auditor con este plan-draft.json y este gate — este script no evalua juicio semantico." }
```

con exit code 2 (ni `pass`=0 ni `blocked`=1 — "no evaluable por script", mismo patron conceptual de `validation-run`).

Quien invoca este skill y recibe `requires-agent` debe entonces despachar el agente `bossdream-planner-auditor` pasandole:
- `plan-draft.json` + el `gate` pedido (siempre).
- Para `contradiction`, ademas los ADRs con `status: accepted` de `docs/adr/*.md` (para detectar contradiccion con decisiones previas).

El agente nunca recibe el proyecto completo — solo esos archivos. Su veredicto (`VEREDICTO: pass | blocked` + `RAZON:`) es el resultado final de ese gate; no vuelve a pasar por `plan-checks.ps1`.

## Reporte

- Todos los gates pasan (deterministas en `pass`, semanticos con veredicto `pass` del agente): `plan-checks OK`.
- Algun gate deterministico en `blocked`: `PLAN-PIPELINE FAIL en gate '<id>'` con la `razon` del script.
- Algun gate semantico con veredicto `blocked` del agente: `PLAN-PIPELINE FAIL en gate '<id>'` con la `RAZON` del agente.
