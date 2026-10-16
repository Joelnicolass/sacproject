---
description: "Implementa una feature de gameplay o el slice vertical en el juego Godot: árbol, OK, código, review, playtest."
argument-hint: "[feature]"
---

Implementá **una** feature de gameplay en el **proyecto Godot del juego**. Iterar un slice jugable gana a un PRD que define el título entero.

Esto **no** es `/new-mp-feature` (eso solo scaffoldea un actor MpKit). Esto **no** es `/implement-rfc` (eso sigue un RFC ya escrito). Si ya hay un RFC con ID, usá `/implement-rfc <id>`.

Si está cargada `godot-studio-workflow`, el **orquestador** (este chat) no implementa solo. Corte chico (un componente, sin escena que pueda hacer trampa): el plan queda en este chat. Si hay árbol o `res://debug/`: `studio-tech-lead` → el usuario aprueba el corte **una vez** → `studio-developer` → `studio-reviewer` → `studio-playtester` sobre la escena del `F<n>`. No preguntes otra vez si se juega. Pase visual: preguntá, y sin `VISUAL.md` no hay look. Tester GUT solo si el usuario o RULES lo piden.

Cuando vuelva el playtester, clasificá: criterio roto → developer, una corrección; la escena de debug ya muestra el resultado → reviewer; cache o CLI → este chat reimporta y relanza; falta la escena → `NEED_SETUP`, no un tech lead nuevo.

Cargar `godot-layered-architecture` y `godot-composition-first`. Motion: `godot-animation`. Feel jugoso de un evento ya existente: `/add-juicy` + `godot-juicy`. FSM: `/add-state-machine` + `godot-fsm`. Plataformas 2D: `/add-platformer-2d` + `godot-platformer-2d`. Si hay MP: `godot-mp-kit`. Si no hay MP: no cargues el kit.

## 1. Acotar (antes de código)

Si el pedido es vago, preguntá en un lote (`AskUserQuestion` en Claude Code / `AskQuestion` en Cursor, si está):

1. Qué hace el jugador / qué se ve. Una o dos frases.
2. Dónde vive (escena, actor, HUD). Clean vs estándar **ya elegido**; no lo cambies.
3. ¿Hay red? Si sí: local/WiFi u online. Si no: cero RPCs.
4. 2D / 3D. Arte: placeholder salvo OK + referencias.

No entrevistas un GDD completo. No corras `/create-prd` ni `/generate-rfcs` “por las dudas”.

Fuera de alcance de **esta** feature: anotalo y no lo construyas.

Si el corte cruza sesión + red + varios mundos, proponé un RFC corto y `/implement-rfc`. Si es un componente, HUD, un tipo `.tres`, un estado: seguí acá. Si solo querés feel jugoso sobre algo que ya pega: `/add-juicy`. Si solo querés FSM o perdón de plataformas: `/add-state-machine` / `/add-platformer-2d`.

## 2. Artefactos (crecen, no se regeneran)

- Si existe `FEATURES.md`: agregá el próximo `F<n>` (IDs append-only; nunca renumeres). Criterios de aceptación en 3–8 viñetas.
- Si no existe: creá `FEATURES.md` **solo** con esta feature (F1). No inventes F2–F20.
- Si existe `PRD.md`: como mucho una línea en alcance / no-goals. No reescribas el GDD.
- No hace falta RFC. Si el usuario pide contrato escrito, un `RFCs/RFC-NNN-<slug>.md` mínimo (objetivo + aceptación + árbol).

Autoridad si hay conflicto: PRD.md > FEATURES.md > RULES.md > VISUAL.md > RFC > este plan. Si no hay PRD, gana FEATURES + RULES + lo que el usuario acaba de acotar.

## 3. Tubería (igual que un RFC chico)

### Fase 1 — plan, sin código

`studio-tech-lead` (o este chat si el corte es 1–3 archivos):

- Árbol + mapa de responsabilidades ([file-tree.md](../skills/godot-studio-workflow/file-tree.md))
- Escena de prueba en `res://debug/`: estado inicial fácil, resultado todavía no ocurrido, acción de InputMap. Queda escrita en el `F<n>` (o en el RFC si hay contrato).
- Qué es `.tres`, qué es nodo, qué es `@export`
- Motion: evaluar Tween vs `AnimationPlayer` (skill `godot-animation`); knobs en inspector o timeline
- Checklist de [adding-features.md](../skills/godot-layered-architecture/adding-features.md)

Mostrar el árbol. **Esperar OK** (¿más/menos piezas?).

### Fase 2 — implementar

`studio-developer` sigue el plan. Un nodo no pinta + spawnea + puntúa + cambia de escena.

### Fase 3 — review

`studio-reviewer`: cada criterio de FEATURES (o del RFC corto) con evidencia. Un pase.

## 4. Listo cuando

- El proyecto parsea headless (`godot --headless --path . --quit` sin `SCRIPT ERROR`).
- La feature se ejerce en el editor (F5/F6, una acción).
- Cada criterio del `F<n>` tiene evidencia en el review.
- Timing / squash / feel se tunnea en el inspector si hay animación.
- FEATURES.md tiene el `F<n>` y no se inventó el resto del producto; decisión + próximo paso quedan en memoria si está la skill.
