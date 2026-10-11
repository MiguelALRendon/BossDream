---
name: rules-comentarios
description: Politica universal de comentarios (tolerancia cero a comentarios que explican QUE hace el codigo, bloques multi-linea, breadcrumbs de IA y separadores decorativos). Companero en contexto del hook comment-check que la aplica de forma determinista. TRIGGER — antes de escribir o mostrar cualquier bloque de codigo en cualquier lenguaje.
---

# Politica de comentarios — tolerancia cero

Antes de escribir codigo en cualquier lenguaje, escanear linea por linea. Si hay un comentario que no cumple estas reglas, eliminarlo antes de outputear. Aplica a snippets de 1 linea, archivos completos, CSS, SQL, todo.

## Prohibido

- Cualquier bloque multi-linea: `/* */`, `/** */`, `//` consecutivos (2+ lineas), `@* *@` multi-linea.
- Comentarios que explican QUE hace el codigo.
- Breadcrumbs de IA: `// Added for X`, `// This handles...`, `// Updated to...`.
- Tono conversacional, casual o narrativo.
- Redundancia con el nombre del simbolo.
- Separadores decorativos: `/* ===== */`, `// -------`, `#region`.

## Unico permitido — 1 linea, WHY no inferible

Solo cuando la razon no puede deducirse leyendo el codigo:

```
// XPO requiere AfterConstruction, no constructor, para inicializar colecciones
// Orden importa: primero Commit, luego NotifyChanged
```

Si el WHY es deducible → silencio total.

## XML docs de IDE (C# ///)

Max 3 lineas (`<summary>` + `<param>` + `<returns>`), solo en APIs publicas de libreria o interfaces de contrato, tono de especificacion. Prohibido `<remarks>`, `<example>`, parrafos narrativos.

## Enforcement

El hook `comment-check` (PreToolUse Edit|Write) bloquea de forma determinista los bloques multi-linea, separadores, regions y breadcrumbs antes de escribir. Esta skill es la referencia; el hook es el muro.
