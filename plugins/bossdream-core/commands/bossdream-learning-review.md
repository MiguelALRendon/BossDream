---
name: bossdream-learning-review
description: Corre el gate de 4 etapas de bossdream-learning (evidence_gate/pattern_consistency_gate deterministas + validacion/aprobacion humana) sobre un patron detectado, y si pasa, ofrece publicarlo como tutorial procedural. TRIGGER — el usuario quiere revisar si una operacion repetida (ej. registrar TC-XXX) ya califica para publicarse como tutorial reusable.
disable-model-invocation: true
arguments:
  - name: slug
    description: "slug del tutorial candidato (ej. registrar-tc-nuevo) — debe existir .bossdream-project/human-explanations/<slug>.md ya redactado"
---

# /bossdream-learning-review — revisar y publicar un patron aprendido

Punto humano de `bossdream-learning`: las 2 primeras etapas del gate son deterministas, las 2 ultimas (`validacion`/`aprobacion`) son una decision de persona que este comando pide en vivo — nunca las asume ni las infiere (mismo criterio que `validation-mark-mechanical.ps1`).

## Pasos

1. **Localiza el proyecto activo** (`.claude/.active-project`) y arma la ruta del log: `bossdream_projects/<slug-de-proyecto>/.bossdream-project/operations-log.jsonl`.
2. **Primera corrida — solo deterministica**: `scripts/bossdream-learning-gate.ps1 -Slug <slug> -OperationsLog <ruta del paso 1>` (sin `-ValidacionVeredicto`/`-AprobacionVeredicto`).
   - Si el resultado bloquea en `evidence_gate` (log vacio o inexistente): dilo tal cual y PARA — no hay nada que revisar todavia.
   - Si bloquea en `pattern_consistency_gate` (menos de 3 repeticiones consistentes del mismo `script`/parametros/`resultado`): dilo tal cual, cita `candidatos[]` si el script devolvio alguno cerca del umbral, y PARA.
   - Si ambas etapas deterministas pasan: continua al paso 3.
3. **Presenta el patron detectado al usuario**: que script, que parametros, cuantas repeticiones, y el tutorial candidato (`.bossdream-project/human-explanations/<slug>.md` si existe — si no existe, dilo: hace falta redactarlo antes de seguir, PARA).
4. **Pide `validacion`**: pregunta al usuario si el patron detectado es realmente valido (no un falso positivo de agrupacion) — nunca asumas `pass`. Si dice que no, PARA sin correr `aprobacion`.
5. **Pide `aprobacion`**: pregunta al usuario si aprueba publicar este tutorial. Nunca asumas `pass`.
6. **Segunda corrida — con los veredictos del usuario**: `scripts/bossdream-learning-gate.ps1 -Slug <slug> -OperationsLog <ruta del paso 1> -ValidacionVeredicto <pass|blocked> -AprobacionVeredicto <pass|blocked>` (agregando `-ValidacionDetalle`/`-AprobacionDetalle` con lo que el usuario haya dicho, si algo).
7. **Si el resultado final es `pass`**: ofrece correr `scripts/bossdream-learning-publish.ps1 -Slug <slug>` — solo si el usuario confirma. Si corre, reporta la ruta de destino que el script imprime.
8. **Si el resultado final es `blocked`** (el usuario dijo `blocked` en validacion o aprobacion): reporta el motivo tal cual el log lo registro y PARA — nunca publiques sin `aprobacion: pass`.

## Reglas

- Nunca invoca `bossdream-learning-publish.ps1` sin haber corrido antes el gate completo con resultado `pass`.
- Nunca asume `validacion`/`aprobacion` — son siempre la respuesta literal del usuario en esa corrida, nunca heredadas de una corrida anterior.
- Un tutorial rechazado en `aprobacion` puede volver a revisarse mas tarde (nueva corrida de este comando) si el usuario cambia de opinion — el log queda como evidencia de ambas corridas.
