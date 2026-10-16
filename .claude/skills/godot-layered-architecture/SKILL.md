---
name: godot-layered-architecture
description: >-
  Elige y aplica arquitectura Godot 4 (GDScript): Clean en capas (domain
  RefCounted, core autoloads, features) o estándar por escenas y scripts
  pequeños. Siempre pregunta al usuario cuál usar. Prioriza composición,
  Resources (.tres) como plantillas de tipo, editor y componentes
  reutilizables. Usar al crear o modificar un proyecto Godot, GDScript,
  escenas, reglas de partida, features, HUD o al arrancar un juego nuevo.
---

# Godot — arquitectura

Base para juegos Godot 4 (GDScript). Hay **dos estilos** válidos. El agente **no asume Clean**.

Siempre cargar también [godot-composition-first](../godot-composition-first/SKILL.md). Tests: [godot-testing](../godot-testing/SKILL.md). Multiplayer: **preguntar** (ninguno / local-WiFi / online) — [godot-mp-kit](../godot-mp-kit/SKILL.md) solo si hay MP. 2D/3D: **preguntar**; si es 3D, MCP Blender solo con OK. Un título nuevo o un RFC: [godot-studio-workflow](../godot-studio-workflow/SKILL.md).

## Prioridades (siempre)

Siempre se priorice:

- arquitectura facil de escalar y limpia en capas
- siempre tienen prioridad las estructuras de composicion
- siempre tienen prioirdad los nodos y las configuraciones sobre el editor
- siempre se debe dar prioridad a la reusabilidad de los componenetes

En el camino **estándar**, “capas” **no** significa carpetas `domain/core/features` ni scaffoldear Clean. Significa scripts chicos, una responsabilidad por pieza, y composición de nodos/Resources. El bullet de capas de arriba aplica al camino Clean; en estándar no se inventa `src/domain/`.

## 1. Elegir estilo (obligatorio)

**Preguntar siempre** al usuario, con la tool de preguntas (`AskUserQuestion` en Claude Code / `AskQuestion` en Cursor, si está), **antes** de crear carpetas, autoloads o una feature que fije la forma del proyecto.

1. **Clean / en capas** — `features → core → domain`. Ver [clean.md](clean.md).
2. **Estándar Godot** — escenas + scripts junto a la escena. Ver [standard.md](standard.md).

No preguntar de nuevo si: el usuario ya eligió en este chat; pidió un estilo por nombre; o el repo **ya lo declara** **y** el trabajo es sobre ese mismo juego.

Si no hay respuesta, **no** scaffoldear `src/domain/` ni un `scripts/` gigante.

## 2. Lineamientos comunes

| Prioridad | En código |
|-----------|-----------|
| Composición | Árbol + packed scenes. No superclase de 800 líneas. |
| Editor | Knobs en `@export` y `.tscn`. No pisar el inspector en `_init`/`_ready`. |
| Resources | Tipos de contenido = `class_name` + `.tres`. Una escena, muchos datos. |
| Reuso | Extraer a `shared/` o `addons/` al segundo caller. |
| Scripts chicos | Una responsabilidad. Si crece, hijo o componente. |
| Señales | Nombre en **pasado**, tipadas (`signal died(who: Node)`). El padre conecta; el hijo no nombra al padre. |

### Escenas autónomas (docs Godot)

Diseñá cada packed scene para correr **sola** (F6). Sin deps externas. Si necesita al mundo: el **padre inyecta** (`@export var health: Health`). SceneTree es **relacional**, no espacial: hijo solo si al borrar el padre debe borrarse el hijo; si no, sibling + `RemoteTransform2D`/`RemoteTransform3D`. Split típico: `Main` persistente, `World` (se swapean niveles), `GUI` hermana (no se borra con el nivel).

### Dónde vive el dato (no todo es autoload)

| Qué | Usar | No |
|-----|------|-----|
| Dato de tipo / catálogo | `class_name` `Resource` + `.tres` | Autoload con stats |
| Helpers puros | `class_name` + `static func` | Singleton vacío |
| Comportamiento de un actor | Nodo `class_name` hijo / packed scene | Manager global |
| Servicio global, aislado, sobrevive `change_scene` | Autoload (MpKit, bus de eventos) | Autoload que guarda nodos visuales o el puntaje de *esta* ronda |
| Puntaje / vidas de *esta* partida | Nodo `Match` (o sesión Clean si sobrevive el cambio de escena) | `ScoreManager` eterno |

UI en el idioma del producto; identificadores de código en inglés.

## 3. Datos: qué va dónde

| Cosa | Dónde |
|------|--------|
| Catálogo de tipos (proyectil A vs B, enemigo scout vs tank) | **Resource** `.tres` |
| Look de *esta* instancia | `@export` en el nodo / material |
| Reglas de ronda (duración, vidas, layers) | `MatchRules.tres` (o constantes únicas). No literales copiados. |
| HP actual, cooldown en curso | Runtime en el nodo; **no** mutar el `.tres` |

## 4. Cómo agregar una feature

Checklist: [adding-features.md](adding-features.md). Tests: [godot-testing](../godot-testing/SKILL.md).

| Tipo | Dueño | Ejemplos |
|------|--------|----------|
| **A. Input** | Cliente lee; host aplica | acciones InputMap |
| **B. Simulación** | Solo host si hay red | proyectil, enemigo |
| **C. Estado de partida** | Sesión Clean o nodo Match | munición, vidas |
| **D. Presentación** | Local | flash, post-proceso |
| **E. UI** | HUD / menús | icono cooldown |
| **F. Definición de tipo** | Resource plantilla | `projectile_fast.tres` |

## 5. IDs (si hay multiplayer)

Slot lógico = HUD/vidas. Peer ENet = solo RPC. HUD: `MpKit.local_slot()` (0 = proceso dedicated, no hay jugador). Nunca `get_unique_id()`.

## Anti-patrones

- `World.gd` que pinta, spawnea, puntúa y cambia de escena.
- `if kind == "fast"` en el proyectil en vez de un `.tres`.
- Mutar un Resource compartido (`data.damage = 3`).
- Feature nueva por herencia profunda.
- Autoload para algo que es un nodo o un Resource.

Ejemplos: [examples.md](examples.md).
