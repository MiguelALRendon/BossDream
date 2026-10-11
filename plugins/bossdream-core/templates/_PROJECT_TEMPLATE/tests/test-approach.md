# Enfoque de Pruebas — [Nombre de la iniciativa]

**ID de iniciativa:** REQ-XXX
**Clasificación:** Simple / Medio / Complejo

> **AVISO:** este documento se genera crudo, con placeholders — requiere llenado manual completo antes de `/bossdream-validate`. Los casos de prueba formales individuales viven en `cases/TC-XXX.md` (uno por archivo, vía `/bossdream-testcase`) — no se embeben aquí.

---

## 1. Cuándo usar checklist vs. casos de prueba formales

| Nivel | Enfoque |
|---|---|
| **Simple** | Solo checklist de smoke test (sección 2). No se crean casos de prueba formales. |
| **Medio** | Checklist + casos de prueba formales (`cases/TC-XXX.md`) solo para lo crítico y para lo que tenga lógica condicional relevante. |
| **Complejo** | Casos de prueba formales completos + regresión + prueba de integración si aplica + revisión de seguridad si toca datos sensibles. |

---

## 2. Checklist de smoke test (Simple, y como base en Medio/Complejo)

- [ ] La funcionalidad principal responde sin errores.
- [ ] No se rompió nada que funcionaba antes (revisión rápida de lo relacionado).
- [ ] Los datos se guardan/consultan correctamente en el ambiente de pruebas.
- [ ] El usuario que validó (UAT) confirmó que ve lo esperado.

**Evidencia mínima:** captura de pantalla o confirmación escrita de quien ejecutó la checklist — guardar en `evidencia/`.

---

## 3. Casos de prueba formales — ver `cases/TC-XXX.md`

Los casos de prueba individuales (Medio y Complejo) se generan uno por uno vía `/bossdream-testcase` usando la plantilla `_templates/test-case.md`. No se listan en este archivo para evitar reescribir un documento monolítico en cada caso nuevo — ver tabla resumen abajo (sección 7) para el estado agregado.

---

## 4. Regresión (Medio y Complejo)

Lista de funcionalidades existentes que podrían verse afectadas por este cambio y que deben re-verificarse:

- [ ] [Funcionalidad existente 1]
- [ ] [Funcionalidad existente 2]

---

## 5. Pruebas de integración (cuando aplica)

Para iniciativas que involucran comunicación entre sistemas:

| Sistema origen | Sistema destino | Escenario probado | Resultado |
|---|---|---|---|
| | | | |

---

## 6. Revisión de seguridad (Complejo, cuando toca datos financieros/nómina o sensibles)

- [ ] Los datos sensibles no quedan expuestos en logs, respuestas de API o pantallas sin control de acceso.
- [ ] Los permisos/roles de acceso se validaron para el nuevo flujo.
- [ ] Si aplica, se validó que la integración usa un canal seguro.

---

## 7. Resumen de evidencia para cierre de QA

| Total de casos | Pasaron | Fallaron | Bloqueados | ¿Listo para UAT? |
|---|---|---|---|---|
| | | | | Sí / No |

> Esta tabla la actualiza `testcase-register.ps1` cada vez que se registra un `TC-XXX.md` nuevo — no editar a mano el conteo.
