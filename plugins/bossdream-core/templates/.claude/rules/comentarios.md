---
paths: ["**/*.cs", "**/*.razor", "**/*.sql", "**/*.css", "**/*.scss", "**/*.ps1"]
---

# Comentarios — tolerancia cero

Prohibido: bloques multi-linea (`/* */`, `/** */`, `//`/`#`/`--` en 2+ lineas seguidas segun el lenguaje, `@* *@` multi-linea, `<# #>` multi-linea en PowerShell), comentarios que explican QUE hace el codigo, breadcrumbs de IA (`// Added for X`), tono narrativo, redundancia con el nombre del simbolo, separadores decorativos y `#region`.

Unico permitido: 1 linea con WHY no inferible del codigo. Si el WHY es deducible → silencio.

XML docs (C# `///`): max 3 lineas, solo en APIs publicas de libreria o interfaces de contrato.

**El comentario correcto depende del lenguaje del archivo** — el hook `comment-check` solo aplica el patron del dialecto real de cada extension (`.sql` → `--`; `.ps1`/`.psm1`/`.psd1` → `#` y `<# #>`; `.cs`/`.js`/`.ts`/`.razor`/etc. → `//` y `/* */`; `.razor`/`.cshtml` ademas `@* *@`). Un `--flag` de CLI en un `.ps1`, o cualquier texto que solo *parezca* comentario de otro lenguaje, no se evalua contra el patron equivocado.

El hook `comment-check` bloquea las violaciones antes de escribir.
