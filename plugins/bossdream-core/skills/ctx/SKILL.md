---
name: ctx
description: Dimensiona el contexto minimo necesario para una tarea antes de buscar o codear, para ahorrar tokens. Lista archivos minimos con lineas exactas, preguntas clave, que excluir, dependencias ocultas y complejidad. TRIGGER — al inicio de cualquier tarea no trivial (fase 0 del flujo `bossdream`), antes de disparar busquedas o lecturas amplias.
---

# ctx — dimensionar el contexto

Antes de codear, analiza que informacion es realmente necesaria.

1. **Archivos minimos necesarios**: los 3-5 mas relevantes con path exacto y las lineas a leer (`archivo.ext:50-120`), no el archivo completo.
2. **Preguntas clave a responder primero**: 2-3 cuya respuesta desbloquea la implementacion. Si `codebase-memory` esta disponible, respondelas con el grafo.
3. **Lo que NO necesito ver**: enumera explicitamente lo excluible.
4. **Dependencias ocultas**: con Serena/LSP (`find_referencing_symbols`) si esta, identifica que otro codigo usa las entidades involucradas.
5. **Estimacion**: archivos a modificar (N), riesgo de regresion (bajo/medio/alto), ¿requiere razonamiento estructurado? (si/no).

## Formato

```
ARCHIVOS: [path:lineas, ...]
PREGUNTAS: [1. ... 2. ... 3. ...]
EXCLUIR: [que ignorar]
DEPENDENCIAS: [que usa esto]
COMPLEJIDAD: archivos=N, riesgo=X, seq-thinking=X
```

Objetivo: que la implementacion cueste el menor contexto posible sin perder lo necesario.
