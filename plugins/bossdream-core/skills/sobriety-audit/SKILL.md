---
name: sobriety-audit
description: Audita la sobriedad del framework - detecta componentes (agentes/gates/artefactos/plugins) que declaran reemplazar a otro ya existente sin justificacion. TRIGGER - el usuario pide revisar si BossDream tiene componentes duplicados o redundantes.
disable-model-invocation: true
arguments:
  - name: scope
    description: "unico valor soportado: framework"
  - name: components
    description: "opcional - ruta a components-registry.json; sin el, introspecciona agents/skills/scripts reales del repo"
---

# sobriety-audit — Principio de Sobriedad

Self-audit de complejidad propia: detecta si BossDream acumulo un componente que duplica a otro sin justificacion.

## Uso

```
pwsh -File scripts/sobriety-audit.ps1 -Scope framework
pwsh -File scripts/sobriety-audit.ps1 -Scope framework -Components <ruta a components-registry.json>
```

Sin `-Components`: introspecciona el repo real via `Get-ChildItem` sobre `agents/*.md` (tipo `agente`), `skills/*/` (tipo `gate`) y `scripts/*.ps1` (tipo `artefacto`) del propio plugin — como los artefactos reales no traen campo `reemplaza_a`, cada uno se reporta `justificado: true` con razon generica.

Con `-Components`: audita la lista explicita del JSON (modo determinista para pruebas).

## Regla determinista

SOLO si el campo `reemplaza_a` de un componente tiene el nombre literal de OTRO componente del mismo array, ESE componente (el que declara `reemplaza_a`) es `justificado: false`, con `razon` citando el nombre literal de `reemplaza_a`. Nunca se infiere redundancia por similitud de `descripcion` sin este campo explicito — sin juicio semantico, es comparacion estructural pura (mismo patron que los 8 gates deterministas de Plan Checks).

## Salida

JSON con `componentes[]`, cada elemento `{nombre, tipo, justificado, razon}` — `razon` nunca vacia. Exit code `0` siempre que el registro se pudo leer (o no se paso, en modo introspeccion); exit code `1` si `-Components` apunta a un archivo inexistente.

## Reporte

- Todos los componentes `justificado: true`: `sobriety-audit OK`.
- Algun componente `justificado: false`: `SOBRIETY-AUDIT FAIL en '<nombre>'` con la `razon` reportada.
