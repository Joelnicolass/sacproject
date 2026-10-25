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
  README.md            10 líneas: qué es · quién habla con quién · cómo agregar uno · cómo se verifica (debug/suite)
  <system>.tscn        la escena compuesta (la raíz es un nodo flaco)
  <system>.gd          ≤150 líneas (raíz de un actor replicado: ≤200)
  <part>.gd/.tscn      un hijo por responsabilidad
  <system>_rules.gd    static, RefCounted, sin árbol (se puede probar sola)
  states/              solo si hay ≥3 estados (FsmKit)
data/<system>/*.tres   instancias con nombre humano (trogg.tres, no ycro.tres; el tag queda como campo)
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

## 2b. Todo en el editor, movible con gizmo, sin capas de abstracción (RFC-055 §15)

Regla del usuario: lo que se ve, se mueve o se mide en el juego es un nodo en una escena que se arrastra con el gizmo; el código no inventa alturas, no arma nodos y no busca recursos por texto. El lint cuenta con grep (patrones aproximados) y sube el listón: solo puede bajar.

| # | Regla (una frase) | Qué cuenta el lint | Allowlist |
|---|---|---|---|
| C15 | Un nodo de contenido vive en el `.tscn`, no nace con `.new()`. | `X3D/X2D/...Player/Timer/Light/Camera.new(` en `scenes/` (sin comentarios, sin Transform/Basis/Vector) | `fx_bus`, `sound_bus`, `fx_light_layer`, `mesh_planter`, `patch_planner`, `grass_field`, `npc_spawn` |
| C16 | Una posición es un `Marker3D`, no `Vector3.UP * altura`. | `Vector3.UP *` con número o nombre `height/offset/lift/reach/spread/_h`, y `const [A-Z_]*(HEIGHT\|OFFSET\|LIFT\|REACH\|SPREAD)` | ninguna |
| C17 | Un FX o sonido es un Resource tipado, no un texto. | `FxBus.<fn>("...")` y `@export` String/StringName con nombre fx/sfx/sound/effect | ninguna |
| C18 | Gameplay no busca contenido por tag de texto: recibe el Resource por `@export`. | `GameData.(creature\|spell\|ability\|wizard\|god\|book)*(`, `BodyCatalog.(info\|pose\|has_model)(`, `MapCatalog.`, `GameModeCatalog.` | spawners (`*spawn*.gd`), `scenes/net/`, `scenes/core/catalog/` |
| C18b | Lo mismo para las búsquedas por id que C18 no ve: la pantalla o el gameplay reciben el Resource, solo los catálogos y el cable convierten texto en Resource. | `GameCatalog.shared().god(`/`.building(`, `TypeRef.`, `AiProfile.for_god(`, `BiomeRules.has_look(`, `MatchWire.decode_` en `scenes/` | spawners, `scenes/net/`, `scenes/core/catalog/` |
| C19 | Un `.tres` de `data/` no guarda posiciones: eso es un nodo. | archivos `.tres` en `data/` con `*_offset/_position/_origin/_transform/_pos`, `position*`, `offsets`, `origin`, `transform`, `Transform3D(`. `debug/` se informa aparte (`info:`), no sube el listón | `roughness_offset` |
| C20 | Un radio de lugar o de efecto es un `CollisionShape3D`, no un número de `MatchRules`. | `@export` `*_radius/_height/_distance` en `scenes/match/match_rules.gd` | ninguna |
| C21 | Una referencia es un tipo (`PackedScene`, `Resource`), no una ruta en texto. | `@export_file` en `scenes/` | ninguna |
| C22 | Un tiempo que edita un humano va en segundos (`_s`); la simulación lo pasa a ticks con `MatchClock.ticks_for`. | `@export` con `_ticks` o `frames` en el nombre, en `scenes/` (`@export_storage` no cuenta) | `scenes/ui/`, `scenes/net/`, celdas de atlas (`h_frames`, `v_frames`, `frames_h`, `frames_v`, `frames_per_s`), resync de red (`resync_ticks`) |

Antes y después (C16 + C15):

```gdscript
# Antes: la altura vive en el código y no se ve en el editor.
var muzzle := body.global_position + Vector3.UP * muzzle_height
var flash := OmniLight3D.new(); add_child(flash)

# Despues: el socket es un Marker3D de la escena; la luz es un hijo del .tscn.
@export var muzzle: Marker3D
@export var flash: OmniLight3D
var muzzle_pos := muzzle.global_position
```

## 2c. Lineamientos del proyecto (los pidió el usuario; valen igual que las reglas)

- **La meta de todo (2026-10-24).** Cada sistema se diseña para que un humano pueda **entender, modificar, agregar, quitar, crear y escalar** fácilmente, sin leer código ni el original. El plan de cada corte trae una tabla corta «cómo lo hace un humano» con esos seis verbos (qué abre, qué toca en el inspector o el viewport, cuántos archivos), por ejemplo: «agregar un hechizo = duplicar un `.tres` y una escena, asignarlo en el libro del dios». Si un verbo pide código nuevo o más de dos lugares, el diseño se revisa antes de implementar.
- **Human first, Godot priority.** Se programa como cualquier juego Godot moderno. Nada de calcar el código del 2000: sacengine y el original dicen QUÉ hace el juego, nunca CÓMO.
- **Un dueño por estado.** Si dos cosas escriben el mismo estado, se hace un componente único, derivado e idempotente; nada de parches de orden (`call_deferred` encadenados, banderas de «ya lo hice»).
- **Nada disperso.** Lo que un humano edita junto vive en UN lugar que se abre y se ve en el viewport, con nodos estándar de Godot. Sin cadenas de `.tres` que se referencian entre sí cuando una escena o un recurso embebido alcanza.
- **Pocos scripts genéricos, muchos nodos y `.tres`.** Nunca un script por hechizo, criatura o edificio si una pieza común con knobs alcanza (ejemplo: `StructureAction` para Manalith y Shrine).
- **No inventar.** Todo dato o comportamiento del original se verifica con sacengine (`archivo:línea`), los datos horneados y REA sobre el ejecutable; lo que no se pudo confirmar se marca NO VERIFICADO.
- **Debug para verificar, edición en las escenas reales.** El developer arma lo que necesite en `debug/<sistema>/` (escenas F6, casos de la suite) para verificar su corte. Las herramientas que usa un humano para editar viven en las escenas reales (p. ej. el nodo `Look` del `map.tscn`), nunca solo en `debug/`, porque `debug/` se borra al terminar el refactor.
- **Portable.** Sin rutas personales en archivos versionados; el producto no necesita el juego original; las herramientas que sí lo necesitan lo dicen al arrancar.
- **Medible.** Un arreglo visual se cierra con una captura de cámara fija y un criterio numérico, no a ojo.

## 3. README de un sistema (≤10 líneas)

```
# units/vision
What: a creature sees foes inside its Vision area; the side remembers them for `memory_s`.
Not: who to attack (Engagement), what the AI knows (AiPerception).
Talks to: Vision.seen(foe) goes up to UnitBody -> Engagement; SideVision listens to every Vision.seen.
Edit: unit.tscn/Vision radius_m · data/creatures/<name>.tres vision_m.
Check: debug/units/vision_range.tscn (F6) · rules_suite vision_cases.
```

Las cinco líneas son obligatorias: What / Not / Talks to / Edit / Check. Si el README ya tenía texto cierto y útil, queda debajo de una línea `---`.

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

Otro caso (hecho en 055d-d3): `FloraMap` era `tags = ["CAH1", …]` más `counts: Array[PackedByteArray]` de 320x320. Ahora la flora es un **nodo** (se arrastra, se ve en el árbol, se pinta con cualquier editor de imágenes):

```gdscript
class_name FloraLayer extends Node3D   # hijo de Vegetation/ en map.tscn
## Where one kind of plant grows on a map. Paint `density` in any image editor (white = dense).
@export var species: VegetationSpecies   # data/vegetation/species/<nombre>.tres
@export var density: Texture2D           # grayscale PNG, 1 px = cell_m
@export var cell_m := 8.0
@export var max_per_cell := 6
```

Pocas plantas en un lugar: `VegetationPatch` (especie, `radius_m`, `count`, `seed`).

## 5. Checklist del reviewer (por corte)

- ¿Hay un script nuevo >150 líneas?
- ¿El `##` dice qué hace y qué NO hace, sin abrir con el original?
- ¿Un hijo nombra a su padre o a un hermano?
- ¿Hay un socket `@export` sin warning cuando falta?
- ¿Quedó un campo crudo (`flags`, `Dictionary`, String-tipo) en un `.tres`?
- ¿El corte se puede verificar (escena `debug/<sistema>/` con F6, caso en la suite o captura de `agent/harness/`)? ¿Alguna herramienta de edición quedó solo en `debug/`?
- ¿El README del sistema dice quién habla con quién?
- ¿Hay un `MpKit.` nuevo fuera de la allowlist?
- ¿El lint está verde, y bajó el conteo de lo que el corte tocaba?
- ¿Cada escena de actor tiene sus sockets (`Marker3D`) en vez de alturas en código?
- ¿Hay hijos `INTERNAL_MODE` nuevos fuera de flora/grass/previews?
- ¿La tabla «cómo lo hace un humano» del plan se cumple? Entender, modificar, agregar, quitar, crear y escalar: cada uno sin código nuevo y en uno o dos lugares.
