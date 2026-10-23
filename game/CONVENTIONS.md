# Convenciones del código

Este juego se escribe como cualquier juego Godot moderno: composición primero (un nodo flaco con hijos, escenas empaquetadas, `@export`, Resources `.tres`). El Sacrifice original y `sacengine` nos dicen QUÉ hace el juego, nunca CÓMO lo programamos: no copiamos su estructura de 2000. Si un comentario necesita citar el original, la cita va al final en una línea `## Ref:`, nunca en la primera frase.

Cómo se hace cumplir: `tools/lint/conventions.sh` cuenta las infracciones de hoy y falla si alguna sube (ratchet). Cada corte que baja un conteo reescribe `tools/lint/baseline.txt` con `--update-baseline`.

```bash
bash tools/lint/conventions.sh              # un renglón por regla; lista solo las que fallan
bash tools/lint/conventions.sh --verbose    # todos los infractores
bash tools/lint/conventions.sh --update-baseline
```

## 1. Una carpeta es un sistema

```
scenes/<system>/
  README.md            10 líneas: qué es · quién habla con quién · cómo agregar uno · escena de debug
  <system>.tscn        la escena compuesta (la raíz es un nodo flaco)
  <system>.gd          ≤150 líneas (raíz de un actor replicado: ≤200)
  <part>.gd/.tscn      un hijo por responsabilidad
  <system>_rules.gd    static, RefCounted, sin árbol (se puede probar sola)
  states/              solo si hay ≥3 estados (FsmKit)
data/<system>/*.tres   instancias con nombre humano (trogg.tres, no ycro.tres; el tag queda como campo)
debug/<system>/        escenas F6 + variantes .tres
```

## 2. Las reglas

Palabras simples primero; la columna de la derecha dice quién las controla.

| # | Regla | Quién la controla |
|---|---|---|
| C1 | Un script tiene ≤150 líneas. Más de 300 es error salvo allowlist con fecha. | lint (`C1a` >150, `C1b` >300) |
| C2 | Una clase, una responsabilidad: el `##` de arriba dice en una frase qué hace y qué NO hace. | reviewer |
| C3 | Nodos y clases son sustantivos; métodos, verbos; lo privado empieza con `_`; las señales van en pasado (`died`, no `die`). | reviewer |
| C4 | Las señales suben, las llamadas bajan. Un hijo no nombra a su padre ni a sus hermanos. Sin `get_parent()` fuera de `@tool`. | reviewer |
| C5 | Entre escenas se conecta con `@export var health: Health` (con warning si falta); dentro de una escena, `%UniqueName`. Prohibido `get_node("Health")` desde otro nodo. | lint (`C5`) |
| C6 | Los servicios llegan por `@export` o por una `const GROUP` en la clase dueña. Prohibido `get_first_node_in_group("texto")`. | lint (`C6`) |
| C7 | Prohibido `.call("nombre")` y `has_method(` sobre tipos con `class_name`: se llama el método tipado. | lint (`C7`) |
| C8 | Los Resources usan nombres humanos con unidad (`vision_m`, `cooldown_s`). Prohibidos en `*_type.gd`: `flags*`, `folder`, `components`, `Dictionary`, `Array[Dictionary]`, y Strings donde existe el tipo. | lint (`C8`) |
| C9 | El doc cuenta primero qué pasa en el juego, en palabras simples. La cita al original va al final (`## Ref: state.d:…`) y nunca abre el comentario. | lint (`C9`) |
| C10 | FSM solo con ≥3 estados; command/interactor solo con ≥2 llamadores. | reviewer |
| C11 | Herencia propia de profundidad ≤1 (`A extends Node`, `B extends A` y listo). Para más, componé. | lint (`C11`) |
| C12 | `MpKit.` solo vive en `scenes/net/`, en los dueños de `submit_*`/`@rpc` y en los que usan `MultiplayerSpawner`. | lint (`C12`) |
| C13 | El producto no lee formatos del original: nada de `assets/original`, `OriginalAssets.` ni `res://tools` en `scenes/`. | lint (`C13`) |
| C14 | Los logs van por `DebugLog`; sin `print(` en `scenes/`. | lint (`C14`) |

Los identificadores van en inglés; el texto de UI, en el idioma del producto.

## 3. README de un sistema (≤10 líneas)

```
# units/vision
What: a creature sees foes inside its Vision area; the side remembers them for `memory_s`.
Not: who to attack (Engagement), what the AI knows (AiPerception).
Talks to: Vision.seen(foe) goes up to UnitBody -> Engagement; SideVision listens to every Vision.seen.
Edit: unit.tscn/Vision radius_m · data/creatures/<name>.tres vision_m.
Debug: debug/units/vision_range.tscn (F6).
```

Las cinco líneas son obligatorias: What / Not / Talks to / Edit / Debug. Si el README ya tenía texto cierto y útil, queda debajo de una línea `---`.

## 4. Datos: antes y después

Hoy `BuildingType` guarda `flags = 2147491848`, `ground = true`, `tileset = "char"`, `folder = "joby.WAD!/ch_a.FLDR"` y `components = [{destroyed, facing, kind, spell, tag, x, y, z}]`: nadie sin el original lo entiende. Así debería ser:

```gdscript
class_name BuildingType extends Resource
## A building on the map: how it looks, how hard it is to destroy, who hides in it.
@export var display_name := "Casa"
@export_range(0, 20000) var max_health := 0        ## 0 = cannot be destroyed
@export var shelters_peasants := false
@export var flattens_ground := false
@export var scene: PackedScene                       ## the parts as child nodes, placed with the gizmo
@export var ruin_scene: PackedScene                  ## what stays when it falls (empty = nothing)
@export var tag := ""                                ## network id, derived; read-only in the inspector
```

Las partes pasan a ser nodos hijos de `scene`; la colisión sale de la escena.

Otro caso: `FloraMap` hoy es `tags = ["CAH1", …]` más `counts: Array[PackedByteArray]` de 320x320. Después:

```gdscript
class_name FloraLayer extends Resource
## Where one kind of plant grows on a map. Paint `density` in any image editor (white = dense).
@export var species: VegetationSpecies
@export var density: Texture2D        ## grayscale PNG, 1 px = cell_m
@export var cell_m := 8.0
@export var max_per_cell := 6
```

## 5. Checklist del reviewer (por corte)

- ¿Hay un script nuevo >150 líneas?
- ¿El `##` dice qué hace y qué NO hace, sin abrir con el original?
- ¿Un hijo nombra a su padre o a un hermano?
- ¿Hay un socket `@export` sin warning cuando falta?
- ¿Quedó un campo crudo (`flags`, `Dictionary`, String-tipo) en un `.tres`?
- ¿Hay una escena `debug/<sistema>/` que corre con F6?
- ¿El README del sistema dice quién habla con quién?
- ¿Hay un `MpKit.` nuevo fuera de la allowlist?
- ¿El lint está verde, y bajó el conteo de lo que el corte tocaba?
