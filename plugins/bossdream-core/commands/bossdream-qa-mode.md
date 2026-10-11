---
name: bossdream-qa-mode
description: Fija el modo de QA persistente del proyecto (`bossdream.json > qa.mode`) que usan `qa-run` y el QA Increment. Valores optimo, agresivo o costoso (default). No es `/bossdream-mode`, que declara el tipo de tarea. Sin argumento muestra el modo actual.
disable-model-invocation: true
arguments:
  - name: modo
    description: "optimo | agresivo | costoso. Sin valor: solo muestra el modo vigente."
---

# /bossdream-qa-mode — modo de QA del proyecto

1. Lee `bossdream.json > qa.mode`. Si el campo no existe, el modo vigente es `costoso`.
2. Sin argumento: informa el modo vigente y una linea de lo que hace cada uno (`optimo` ahorra tokens, `agresivo` paraleliza con un `bossdream-coder` por caso, `costoso` ejercita todos los casos obligatorios con navegador y datos de solo lectura cuando aplican).
3. Con argumento: si no es exactamente `optimo`, `agresivo` o `costoso`, rechazalo, lista los 3 valores y NO modifiques nada. Si es valido, escribe solo `qa.mode` en `bossdream.json` (crea el objeto `qa` si falta), conservando el resto del archivo, y confirma el cambio.

El cambio es persistente: `qa-run` y `qa-increment` lo usan sin volver a preguntar. Un `--modo` explicito en `qa-run` lo supera solo para esa corrida.
