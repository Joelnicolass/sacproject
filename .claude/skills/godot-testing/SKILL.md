---
name: godot-testing
description: >-
  Testea proyectos Godot 4 con GUT (GDScript) o GdUnit4 (C#). Usar al escribir
  tests unitarios, de escena, CI headless, Resources, señales, domain
  RefCounted, o al elegir un runner de tests de Godot.
---

# Godot — tests

No inventes un runner. Detectá el que ya está (GUT, GdUnit4, script del repo). Si no hay y el usuario pidió tests: **GUT** para GDScript, **GdUnit4** si el proyecto es C#. No instales un framework sin decirlo.

Arquitectura: [godot-layered-architecture](../godot-layered-architecture/SKILL.md). Composición: [godot-composition-first](../godot-composition-first/SKILL.md).

## Qué testear

| Capa | Cómo |
|------|------|
| Domain Clean (`RefCounted`) | `MyRule.new()` en GUT/GdUnit. Sin escena, sin autoloads. |
| Resource de tipo | Cargar `.tres` o construir el Resource; no mutar el asset compartido. |
| Nodo / componente | Añadir como hijo del test; **autofree** (`add_child_autofree` en GUT). Probar señales. |
| Feel / cámara / juicy | Playtest anotado. Un unit test verde no prueba que se sienta bien. |

No tests de relleno. Cada test debe **fallar** si un criterio de aceptación se rompe.

## GUT (GDScript)

- Tests en `res://test/` (o la carpeta que ya use el proyecto).
- `extends GutTest`.
- Nodos: `add_child_autofree(scene.instantiate())` — no dejes nodos huérfanos.
- Señales: `watch_signals(node)` / `assert_signal_emitted`.
- Input: helpers de GUT (`GutInputSender`) y **limpiar** en teardown.
- Headless / CI: binario Godot `--headless -s addons/gut/gut_cmdln.gd` (ajustá al `project.godot` real). Pegá la salida.

## GdUnit4 (C#)

- Usar el runner de GdUnit4 del proyecto. Scene runner / `simulate_action_*` según su API.
- No mezcles GUT y GdUnit4 en el mismo título sin motivo.

## CI

Preferí `godot --headless` + el commandline del runner. “npm test” / typecheck TS no aplican.

## Anti-patrones

- Instalar GUT “por las dudas” en un juego que el usuario no quería tests.
- Testear el `.tscn` entero para una suma en domain.
- Dejar nodos sin free.
- Afirmar cobertura de feel con un `assert_eq` de un float de shader.
