---
name: godot-visual-qa
description: >-
  Review UI/UX de una feature Godot 4 vía captura: jerarquía, contraste,
  consistencia vs VISUAL.md y referencias del usuario. Usar cuando el usuario
  quiere un pase visual o cuando se invoca studio-visual. Pedí estilo y
  referencias primero; no inventes un look.
---

# Visual QA (fidelidad y consistencia)

Especialista UI/UX. No rediseña el juego ni reescribe sistemas. Confronta **captura real** contra `VISUAL.md` y las referencias que dio el usuario.

## 0. Sin guía, no inventes

Si no hay `VISUAL.md` ni referencias en el prompt:

1. Parar.
2. Pedir al orquestador que pregunte estilo (pixel, FUT, flat, …), 2–5 referencias (imagen/URL), y no-goals de look.
3. Recién entonces `/create-visual-guide` o un `VISUAL.md` corto.

Sin eso, un “se ve bien” es vibes, no spec.

## 1. Capturá

Misma receta que skill `godot-playtest` (módulo [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest)): viewport del `project.godot`, escena de la feature, PNG. Si hay `addons/agent_kit/`, usá `cli.sh capture` / `flow` (skill `godot-agent-kit`). Una captura estática **no** basta si el cambio es interacción: ejercé el flujo (un clic, un estado vacío, un error).

## 2. Confrontá

Checklist: [checklist.md](checklist.md). Bloqueante = no se entiende la pantalla, no se puede usar, o contradice `VISUAL.md` / refs.

## 3. Informe

Por hallazgo: ok / problema, escena/nodo, vs qué regla (`VISUAL.md` § o referencia). Adjuntá o citá el path de la captura. No pidas un rebrand.
