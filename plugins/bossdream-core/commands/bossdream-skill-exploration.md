---
name: bossdream-skill-exploration
description: Audita/actualiza el catalogo completo de skills del proyecto — mapea el repo entero, corre tech-debt a nivel de todo el proyecto, y disena con el usuario (via brainstorming) cada skill nueva o desactualizada que tech-debt confirme. TRIGGER — proceso unico y puntual: el usuario lo invoca cuando quiere auditar/actualizar el catalogo completo de skills del proyecto, sin instruccion adicional del usuario sobre que explorar.
disable-model-invocation: true
---

# /bossdream-skill-exploration — auditoria completa del catalogo de skills

Comando delgado — toda la logica vive en la skill `skill-exploration`.

## Pasos

1. Invoca la skill `skill-exploration` sobre el proyecto completo.
2. Reporta el resultado final: las skills creadas/actualizadas (con la ruta de cada `SKILL.md` tocado), o "sin hallazgos" si `tech-debt` no confirmo duplicacion real en ningun area.
