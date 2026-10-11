---
name: bossdream-mode
description: Declara explicitamente el tipo de la tarea actual (el modo). Modos NO-editables (plan, document, review) bloquean toda edicion de codigo. Modos editables sin spec (spike, explore, bugfix, chore) permiten editar rutas de dominio sin frenar para arreglos ad-hoc. `feature` (o sin modo) exige spec en rutas de dominio. `clear` borra el modo. Para EJECUTAR un plan usa `/bossdream-implement`, no este comando.
disable-model-invocation: true
arguments:
  - name: mode
    description: "plan | document | review | spike | explore | bugfix | chore | feature | clear"
---

# /bossdream-mode — declarar el tipo de tarea

Este comando fija `.claude/.work-mode`. **El hook `readiness` lo escribe desde tu prompt literal**, no el modelo — asi la transicion es una decision tuya que el agente no puede falsificar (el mode-lock le impide editar el archivo de modo por su cuenta).

## Modos

**NO-editables** — bloquean TODA edicion de codigo (extensiones de `bossdream.json > codeExtensions`, pobladas por el stack-pack instalado) y de los archivos de control; solo permiten `.md`/`.feature`:
- `plan` — construir el plan (lo fija `/bossdream-plan` automaticamente).
- `document` — escribir/actualizar documentacion.
- `review` — revisar/auditar sin tocar codigo.

**Editables sin spec** — eximen del plan-lock: puedes editar rutas de dominio sin spec activa, para arreglos ad-hoc puntuales:
- `spike`, `explore`, `bugfix`, `chore`.

**Editable con spec**:
- `feature` (o sin archivo) → el plan-lock exige spec en `bossdream.json > planLock.requirePaths`.

`clear` elimina el archivo (equivale a `feature`).

> **Ejecutar un plan NO es esto.** Para implementar un `plan.md` usa **`/bossdream-implement`** (Paso 2): ese comando fija el modo `implement` automaticamente via hook y conduce la ejecucion increment por increment. `/bossdream-mode` es solo para declarar tareas ad-hoc fuera de un plan.

> **Estando en modo `plan`, un pedido chico y NO relacionado con el plan activo (ej. "cambia este icono") NO requiere `/bossdream-implement`.** Ejecutar el plan completo por un cambio de una linea es sobre-ceremonia. El camino correcto es `/bossdream-mode chore` (o `spike`/`bugfix`/`explore`): un comando de una palabra que habilita la edicion puntual sin tocar el plan ni sus increments — el pipeline local del Stop hook sigue corriendo igual antes de "done". Ver `bossdream-plan.md` seccion "Cambios ad-hoc mientras el plan sigue activo".

## La frontera dura (mode-lock)

Pasar de un modo NO-editable a uno editable **requiere que TU lo declares explicitamente** (con `/bossdream-mode <editable>` para ad-hoc, o `/bossdream-implement` para ejecutar un plan). El agente **nunca** puede hacer esa transicion solo: es tu autorizacion, con traza (el archivo queda). No adivina; tu decides cuando se pasa de planear/documentar/revisar a tocar codigo.
