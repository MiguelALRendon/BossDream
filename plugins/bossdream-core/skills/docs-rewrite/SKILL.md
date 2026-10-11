---
name: docs-rewrite
description: Transforma documentacion informal del usuario en documentacion estructurada IA-friendly sin inventar ni perder ideas. Recorre docs del proyecto, valida contra el codigo, detecta contradicciones/duplicidad/obsolescencia, pregunta ante ambiguedad, reorganiza segun Diataxis, mantiene referencias cruzadas y extrae decisiones a ADRs. TRIGGER — el usuario dejo notas en docs/_inbox/, pide ordenar/reescribir la documentacion, o el pipeline corre `docs-rewrite --check`. Modo --check es read-only para CI.
arguments:
  - name: mode
    description: "vacio = reescritura interactiva; --check = read-only, reporta drift, no escribe ni pregunta"
---

# docs-rewrite — documentacion IA-friendly

## Invariantes (no negociables)

1. **Nunca inventa.** Ninguna afirmacion llega a la salida sin anchor VERIFIED (existe en codigo) o USER-ASSERTED (viene del usuario). Sin anchor → se marca, no se escribe.
2. **Nunca borra sin traza.** Toda eliminacion → cross-ref o marca DEPRECATED; el original queda en git.
3. **Pregunta, no adivina.** Ambiguedad bloqueante → una tanda batcheada de preguntas.
4. **Identidad estable.** IDs y numeros de ADR no cambian entre corridas.
5. **Idempotente.** Sin cambios en codigo/docs → cero diff.
6. **Preserva la idea del usuario.** USER-ASSERTED se reformatea, jamas se descarta.

## Estados de anchor

| Estado | Significado | Accion |
|---|---|---|
| VERIFIED | El simbolo/ruta/tabla citado existe en el codigo | Escribir; sellar last_verified |
| USER-ASSERTED | Viene de _inbox (intencion/rationale) | Escribir como concept/decision, source: user |
| STALE | Citaba un simbolo que ya no existe | Marca DEPRECATED, confirmar antes de quitar |
| UNSUPPORTED | Ni codigo ni usuario | No escribir; reportar |
| CONFLICT | Usuario dice X, codigo muestra Y | No decidir; a la tanda de preguntas |

Resolucion en cascada barata: codebase-memory → Serena/LSP → grep. Nunca cargar archivos completos.

## Pipeline

0. Inventario (glob): docs/**, _inbox/**, README, CLAUDE.md. Los `.feature` NO se reescriben (son test), pero SI se ENLAZAN: toda doc de un flujo debe referenciar su `.feature` como fuente de verdad del comportamiento (cablear doc <-> Gherkin). Excluir de reescritura ADR accepted (inmutables), CHANGELOG.
1. Atomizar: partir en unidades; etiquetar tipo y simbolos citados.
1.5. Terminologia: por cada termino de dominio/negocio identificado en la unidad atomizada (distinto de los simbolos de codigo que ya etiqueto el paso "Atomizar"), consultar `docs/catalog/terminology-glossary.md`. Si el concepto ya tiene entrada con un termino distinto al que aparece en el texto nuevo, aplicar esta cascada de arbitraje (al primero que aplique):
   1. Termino anclado en codigo real (variable/tabla/campo/simbolo) — ese gana, sin mas juicio.
   2. Sin anclaje a codigo en ninguno de los dos — preferir el termino tecnico/estandar de la industria sobre una traduccion literal o coloquial.
   3. Sigue sin poder decidirse — no se inventa una resolucion: pasa a la tanda de preguntas batcheadas del paso 5 ("Preguntar"), reusada tal cual, no reimplementada.
   Escribir en el doc final el termino canonico resultante; actualizar (o crear, si es la primera aparicion del concepto) la entrada del glosario con la nueva variante y su evidencia (`archivo:linea`). En modo `--check`: solo detecta y reporta drift de terminologia (variante sin resolver contra el glosario) — nunca escribe el doc ni el glosario, nunca pregunta, mismo comportamiento read-only que el resto del pipeline en ese modo.
2. Anchor: resolver estado de cada unidad.
3. Conflictos: contradiccion / duplicidad (una copia canonica + cross-ref) / obsolescencia.
4. Clasificar Diataxis: human-explanation | to-skill | catalog | concept; dividir docs mixtos.
5. Preguntar: una sola ronda con opciones concretas.
6. Reescribir: front-matter estable + secciones atomicas; extraer decisiones via `/adr-new`; actualizar ARCHITECTURE.md.
7. Cross-refs: reconstruir enlaces, IDs estables, sin rotos.
8. Reporte + vaciar _inbox solo de lo ya procesado.

## Front-matter IA-friendly

```yaml
---
id: ref-slug-estable
title: Titulo
type: reference
status: current
source: both
last_verified: 2026-01-01
symbols: [ClaseA, MetodoB]
related: [adr-0007, to-skill-x]
---
```

## Modo --check (pipeline/CI)

Read-only, no interactivo, no escribe, no pregunta. Emite reporte de drift (incluye drift de terminologia del paso 1.5: variante sin resolver contra `docs/catalog/terminology-glossary.md`); exit ≠0 si hay anchors STALE (drift duro).
