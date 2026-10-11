---
name: bossdream-project
description: Arranca un proyecto de negocio nuevo con gobernanza de documentos SDLC. Desde una idea o documentos de entrada, clasifica Simple/Medio/Complejo, propone Epics/Features cuando aplique, genera requirements.md (incluida su seccion de Reglas de negocio) via docs-rewrite reusado, y deja tests/test-approach.md crudo, con placeholders y el aviso de validacion estricta ya integrado en la plantilla. TRIGGER — el usuario quiere iniciar la documentacion de negocio de una iniciativa nueva, antes de poder correr /bossdream-validate o /bossdream-plan sobre ella.
disable-model-invocation: true
arguments:
  - name: contexto
    description: "la idea/necesidad en palabras del usuario, o una ruta a documento(s) existentes que describan la iniciativa"
---

# /bossdream-project — arrancar un proyecto de negocio

Produce `bossdream_projects/<proyecto>/` completo. Deja `validation.json` en `blocked` — el siguiente paso es siempre `/bossdream-validate`.

## 1. Clasifica (Simple / Medio / Complejo)

Usa la tabla siguiente: el nivel mas alto que se alcance en cualquier fila (esfuerzo, sistemas/empresas involucradas, integraciones nuevas, reversibilidad):

| | Simple | Medio | Complejo |
|---|---|---|---|
| Esfuerzo | ≤3 dias-persona | 4-15 dias | >15 dias |
| Sistemas/empresas | 1 | 2 | 3+ o datos financieros/nomina |
| Integraciones nuevas | 0 | 1 | 2+ |
| Reversible sin impacto | Si | Parcial | No |

## 2. Propone Epics/Features (skill `epic-planner`)

Invoca la skill `epic-planner` pasandole el contexto/documentos de entrada. Nunca se inventan Epics/Features en silencio — se proponen y se confirman con el usuario en una sola tanda. En Simple, `epic-planner` no propone nada (no aplica ningun nivel, ver skill `epic-planner`).

## 3. Nombre del proyecto

Propon 2 nombres de slug (`kebab-case`, sin espacios) derivados del contexto, mas la opcion de que el usuario escriba el suyo. Confirma antes de continuar — el nombre fija la carpeta `bossdream_projects/<slug>/` y no se debe renombrar despues sin coordinacion manual.

## 4. Scaffold

Con nombre, id (`REQ-XXX`, siguiente disponible), clasificacion y slug confirmados, invoca:

```
${CLAUDE_PLUGIN_ROOT}/scripts/project-scaffold.ps1 -ProjectSlug <slug> -ProjectId <REQ-XXX> -ProjectName <nombre> -Classification <Simple|Medio|Complejo>
```

Si el script responde `scaffold SKIP`, el proyecto ya existe — dilo al usuario y sugiere `/bossdream-update-docs` en vez de continuar.

## 5. Generacion de documentos (skill `docs-rewrite`, reusada sin fork)

Invoca `docs-rewrite` sobre `requirements.md` (incluida su seccion de Reglas de negocio, y si `epic-planner` propuso Epics/Features, sobre esos bloques del documento), usando el contexto de entrada como fuente. Respeta sus invariantes: nunca inventa (VERIFIED/USER-ASSERTED/CONFLICT), pregunta ante ambiguedad en una sola tanda batcheada.

**Regla dura sobre los bloques condicionales de `requirements.md`:** segun la clasificacion ya confirmada en el paso 1, **elimina** (no dejes comentado, no dejes el placeholder) los bloques que no apliquen antes de escribir el archivo final:
- **Simple** → elimina el bloque `Epic` y el bloque `Feature` completos; el documento va directo de la nota de uso a `User Stories`.
- **Medio** → elimina solo el bloque `Epic`; conserva `Feature`.
- **Complejo** → conserva ambos.

`tests/test-approach.md` **no se toca en este paso** — queda tal como lo dejo el scaffold (crudo, con placeholders, con el aviso de validacion estricta ya integrado en la plantilla). El usuario debe llenarlo por completo a mano antes de `/bossdream-validate`.

## 6. Cierre

Reporta: proyecto creado, clasificacion, Epics/Features propuestos (si los hubo), y que `validation.json` quedo en `blocked`. Indica al usuario: revisa `tests/test-approach.md` y despues corre `/bossdream-validate`.

## Reglas

- Nunca escribe codigo ni modifica los comandos/scripts core del motor del Delivery Cycle (`bossdream-plan.md`, `bossdream-implement.md`).
- Nunca marca `validation.json` como `ready` — eso solo lo hace `validation-check.ps1`.
- Si el contexto de entrada es ambiguo sobre clasificacion o alcance, pregunta antes de crear el scaffold — no asumas.
