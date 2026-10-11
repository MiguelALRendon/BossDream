---
name: adr-new
description: Crea un Architecture Decision Record en docs/adr/ con formato MADR (numeracion consecutiva, status, context, decision, consequences). TRIGGER — se tomo una decision arquitectonicamente significativa, se cambio una convencion o se descarto una opcion con justificacion. El flujo (Fase 4) lo exige al tocar codigo legado.
disable-model-invocation: true
arguments:
  - name: title
    description: "titulo corto de la decision"
---

# adr-new — Architecture Decision Record

Crea `docs/adr/NNNN-titulo-en-kebab.md` con el siguiente numero consecutivo (max de los existentes + 1, sin reusar), a partir de `docs/adr/0000-template.md`.

## Formato MADR

Front-matter: `status` (proposed | accepted | rejected | deprecated | superseded), `date`, `deciders`.
Cuerpo: **Context and Problem Statement** · **Considered Options** · **Decision Outcome** (opcion elegida + por que) · **Consequences** (positivas/negativas).

## Reglas

- Los ADR son inmutables tras `accepted`: no se editan; si cambia la decision se crea uno nuevo con `status: superseded` que enlaza al anterior, y el viejo se marca superseded-by.
- No inventar drivers/consecuencias no presentes en la decision real.
- La numeracion nunca se reusa aunque un ADR quede deprecated.
