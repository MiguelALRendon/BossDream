# Instrucciones del agente

Este proyecto usa el framework **BossDream**. El flujo detallado y las reglas viven en skills; aqui solo lo esencial.

## Contexto

Core Tenets en @docs/constitution.md. Mapa del sistema en @docs/ARCHITECTURE.md.

## Required Cycle

Tarea no trivial (>1 archivo o >15 lineas netas, decision de arquitectura, ambiguedad, o algo nuevo) → invocar la skill `bossdream` antes de tocar nada. "Done" = gates del `completion.json` en verde con evidencia mostrada, no la palabra "listo" (lo verifica el Stop hook).

## Comentarios

Tolerancia cero. Regla en @.claude/rules/comentarios.md, aplicada de forma determinista por el hook `comment-check`.

## Stack

<completar: lenguaje, framework, ORM, base de datos, convenciones propias del equipo>
