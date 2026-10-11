---
name: helpers
description: Instala las herramientas companeras recomendadas de BossDream (ponytail, HEADROOM, caveman) — per-maquina y opcionales. NO viajan en el plugin porque no son portables; este comando ayuda a instalarlas. Presenta el menu, el usuario elige cuales, corres los pasos y creditas a cada proyecto. TRIGGER — el usuario quiere instalar las herramientas companeras.
disable-model-invocation: true
---

# /helpers — instalar herramientas companeras

Instala las herramientas que **potencian** BossDream pero **no viajan en el plugin** (no son paquetes portables: son archivos/binarios per-maquina). Todas **opcionales**. Presenta el menu, el usuario elige, corres los pasos. **Nunca las metas al plugin.** Credita a cada proyecto.

## Menu (presenta las 3 y pregunta cuales instalar)

### 1. ponytail  (CALIDAD — Simplicity Ladder)
Autor: Dietrich Gebert (`github.com/DietrichGebert/ponytail`, `@dietrichgebert/ponytail`). NO ahorra tokens; su valor es calidad: reta necesidad/tamano de cada cambio. La escalera que el framework usa por todos lados.
Instalacion (scope user):
- Clonar: `git clone https://github.com/DietrichGebert/ponytail <destino>` (o `@dietrichgebert/ponytail` si esta en npm).
- Registrar: `claude mcp add ponytail -s user -e PONYTAIL_DEFAULT_MODE=full -- node "<destino>/ponytail-mcp/index.js"`

### 2. HEADROOM  (TOKENS — compresion de contexto)
MCP en Rust: comprime logs/JSON/AST verbosos a resumenes + ref-tags, y hace scoping de reglas por carpeta. Autor: aswin402.
Requiere Rust (`cargo`). Instalacion:
- Clonar el repo de headroom-mcp y `cargo build --release`.
- Registrar: `claude mcp add headroom -s user -- "<ruta>/target/release/<binario>"`
Aviso: comprime a resumenes -> puede perder fidelidad; proyecto nicho/nuevo. Ponlo a prueba.

### 3. caveman  (TOKENS — salida terse)
SKILL (no MCP) de JuliusBrussee/caveman: hace al agente responder terso, ~65% menos tokens en prosa. Incluye `caveman-shrink` (middleware MCP que comprime descripciones de tools).
Instalacion oficial: `npx skills add JuliusBrussee/caveman -a claude-code`
Aviso: la salida se vuelve terse (choca con "explicar en lenguaje llano"); tiene niveles (lite/full/ultra).

## Reglas
- Todas son per-maquina y opcionales; el plugin NO las empaqueta.
- Confirma cada instalacion antes de correrla; no instales sin que el usuario elija.
- Credita al autor de cada herramienta.
- Si falta un prerequisito (ej. Rust para HEADROOM), avisalo y da el paso para conseguirlo.
- ponytail = calidad; HEADROOM y caveman = economia de tokens.
