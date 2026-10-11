---
name: bossdream-override
description: Llave de emergencia - destraba UNA invocacion de /bossdream-plan o /bossdream-implement bloqueada por validation-lock.ps1, sin desactivar el gate para el resto del proyecto. TRIGGER - el usuario necesita avanzar de urgencia (ej. fix de produccion) con validation.json.overallStatus en blocked y no puede esperar a resolver los hallazgos de Document Validation.
disable-model-invocation: true
arguments:
  - name: motivo
    description: "texto libre, obligatorio - pasado como --motivo=\"<texto>\""
  - name: alcance
    description: "siempre solo-esta-tarea - pasado como --alcance=solo-esta-tarea"
---

# /bossdream-override — llave de emergencia

Uso: `/bossdream-override --motivo="<texto>" --alcance=solo-esta-tarea`.

## Pasos

1. Exige `--motivo` no vacio - sin motivo, no se invoca el script, se le pide al usuario que lo dé.
2. Invoca `scripts/emergency-override.ps1 -Motivo "<motivo>" -Alcance solo-esta-tarea` - agrega una entrada `{quien, cuando, motivo, alcance, consumido: false}` a `.bossdream-project/emergency-overrides.json` del proyecto activo.
3. `validation-lock.ps1` consume esa entrada (la marca `consumido: true`) en la primera invocacion siguiente de `/bossdream-plan` o `/bossdream-implement` que hubiera sido bloqueada - deja pasar esa UNA vez.
4. Reporta al usuario que la entrada quedo escrita y que el gate se reabre normal en la siguiente corrida de `/bossdream-validate` - la llave no desactiva nada de forma permanente.

## Reglas

- Nunca modifica `validation.json` - solo agrega una entrada de auditoria a `emergency-overrides.json`.
- Si no hay proyecto activo (`.claude/.active-project`), el script falla explicitamente - no hay nada que destrabar.
- No toca codigo, no modifica los comandos/scripts core del motor del Delivery Cycle (`bossdream-plan.md`, `bossdream-implement.md`).
