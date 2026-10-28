# Contributing

How code is written in this project. It follows the official Godot guidance and the community tools around it. When an older
project document (`CONVENTIONS.md`, `RULES.md`, folder READMEs) disagrees with this file, **this file wins**.

Sources: [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) ·
[Documentation comments](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html) ·
[Static typing](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html) ·
[Scene organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) ·
[Scenes vs scripts](https://docs.godotengine.org/en/stable/tutorials/best_practices/scenes_versus_scripts.html) ·
[Autoloads vs nodes](https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html) ·
[Godot interfaces](https://docs.godotengine.org/en/stable/tutorials/best_practices/godot_interfaces.html) ·
[Project organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html) ·
[gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) · [GUT](https://gut.readthedocs.io/).

## 0. The rule above the rules: simple and predictable

A developer should guess where a thing lives and change it by opening one or two files.

- "Editor first" means the value sits **on the node that uses it**, visible in the inspector. It does not mean adding a
  resource or a pointer for everything.
- Create a `.tres` only when several things share it, or when a designer edits it as a type (a creature, a spell). Otherwise
  use an `@export` on the node.
- Never point through tags or text (a key that names another resource, a path built from a code). Reference the scene,
  node or resource directly.
- No chains: A → B → C to find one number is a design bug. Flatten it.
- When two designs work, pick the one with fewer files and fewer hops, even if it is less "general".

## 1. Project layout

| Folder | What lives there |
|---|---|
| `scenes/<system>/` | Scenes and the scripts attached to them, one folder per game system (units, spells, wizards, match, ui…) |
| `data/` | `.tres` resources edited in the inspector (creature, spell and building types, AI tactics…) |
| `assets/` | Imported art and sound. `assets/original/` comes from the original game and is read-only |
| `addons/` | Plugins. `mp_kit`, `agent_kit` and `fsm_kit` are external kits: do not edit them here |
| `test/unit/` | GUT tests (`test_*.gd`) |
| `tools/` | Editor and command-line tools (import, bake, audit). The game never loads anything from here |
| `docs/` | `architecture.md` first; everything else is reference or history |

- Files and folders: `snake_case` (`fire_shield.gd`, `fireball.tres`). Nodes: `PascalCase`.
- A file is named after its `class_name` (`class_name FireShield` → `fire_shield.gd`) or after its root node.
- Name things for what they are in the game (`fireball.tres`, `Firefist`), never by the original game's 4-letter codes. When a
  tool needs the original code, keep it in a `source_tag` field inside an `@export_group("Original")`.

## 2. Scenes and nodes

- A game concept (a creature, a spell, a HUD widget) is a **scene**. Its behaviour is nodes you can see in the scene tree, each
  with its values in the inspector.
- **Composition first.** One child node per responsibility (`Health`, `ManaPool`, `Afflictions`). Inheritance is fine for one
  level when it describes a real "is a" (`GameBody extends CharacterBody3D`, `BookEntry extends Resource`).
- A scene that repeats in several places is its own `.tscn` and gets instanced, never copied node by node.
- Big scenes group their children under plain parents (`World`, `Systems`, `Input`, `Hud`, `Audio`).
- Reference other nodes with a typed `@export var health: Health` set in the inspector, or `%UniqueName` inside the same scene.
  Do not use `get_node("Name")` strings, `get_parent()` chains or searches by type at runtime for nodes of your own scene.
- **Parents inject, children do not reach up.** If a child needs its owner, the owner sets it (an `@export` or a setup call).
- Siblings talk through **signals** connected by the common parent (in the scene or in its `_ready`).
- Scenes and resources are referenced with typed `@export var x: PackedScene` / `Resource`, dragged in the inspector.
  Do not build paths from text (`"res://data/shots/" + tag + ".tscn"`), and do not pick a scene by a string key.
- A node created from code is the exception (pools, bullets). Anything that exists once per scene is placed in the `.tscn`.
- A required `@export` that is empty shows a warning in the editor (`_get_configuration_warnings`) **and** fails loudly at
  runtime (`push_error`), never silently.

## 3. Autoloads and global state

- An autoload is for a service that owns its own state for the whole game: `SacrificeFlow` (menu ↔ match), `SoundBus`,
  `FxBus`, the network kit. Nothing else.
- Development tools are not autoloads of the shipped game.
- State that belongs to one match lives in a node of the match scene, not in `static var`.
- `static func` libraries (`class_name X extends RefCounted`) are fine for **pure** rules and math (`CastTime`, `DeathRules`).
  They hold no state.
- Groups are declared as **Global Groups** in Project Settings and named by a constant of their owner (`MatchState.GROUP`).

## 4. GDScript

Follow the [style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html) and let
`gdformat` decide the formatting.

- **Order inside a script:** `@tool` → `class_name` → `extends` → class doc comment → signals → enums → constants →
  `@export` → public vars → private vars (`_x`) → `@onready` → built-in virtuals (`_init`, `_ready`, `_process`…) → public
  methods → private methods.
- **Names:**
  - `PascalCase` for classes and enums;
  - `snake_case` for functions and variables, `_leading_underscore` when private;
  - `CONSTANT_CASE` for constants and enum values;
  - past tense for signals (`died`, `mana_changed`);
  - units in numeric names (`cooldown_s`, `range_m`, `speed_m_s`).
- **Types everywhere:**
  - typed `var` and function signatures;
  - typed collections (`Array[Unit]`, `Dictionary[StringName, int]`);
  - typed access (`wizard.mana.current`, not `wizard.get("mana")`);
  - no `has_method` / `call("name")` on types you know;
  - a typed class instead of a `Dictionary` whose keys are documented in a comment. A `Dictionary` is fine only at the network
    edge, converted with `to_dict()` / `from_dict()`.
- **No magic values:** an enum instead of `0 / 1 / 2`; an `@export` (with `@export_range` and units) instead of a tuning number
  in code; `Engine.physics_ticks_per_second` or `delta` instead of a local `FPS := 60.0`.
- Line length ≤ 100 columns, one statement per line, two blank lines between functions.
- **No fixed limit on script size.** Split by responsibility, not by line count (gdlint warns at 1000 lines and 20 public methods).

## 5. Comments and documentation

- `##` is **API documentation**: it appears in the editor help and as the inspector tooltip of an `@export`. Use it for the class
  (right after `extends`), public members and exports, and say **what it does and what the values mean**.
- `#` is for implementation notes inside functions, only when the code cannot say it by itself.
- Comments describe the code as it is. Development history (RFC numbers, cut names, "used to…") belongs in git and `docs/`, not in code.
- References to the original game's source do not go in code. The mapping lives in `docs/original-mapping.md`.
- A folder README exists only when it says something the code does not, in a few lines.

## 6. Language

- Code, comments, `print`/`push_warning`/`push_error`, editor warnings and inspector group names: **English**.
- Everything the player sees goes through `tr()` with keys in `data/i18n/strings.csv` (Spanish is the default locale).

## 7. Logging and errors

- Development logs go through `DebugLog.on(&"category")`; no bare `print()` in gameplay code.
- `push_error` for a broken setup (missing resource, empty required export), `push_warning` for a recoverable oddity,
  `assert()` for programmer invariants (stripped from release builds).
- Domain refusals (no mana, out of range) are `StringName` constants of `Refusal` or an enum, never free text.

## 8. Multiplayer

- The server (or the host) simulates; clients draw. A node that simulates checks `is_multiplayer_authority()`.
- Network code stays in `scenes/net/` and the owners of `@rpc` / `submit_*`. Replication uses the kit's nodes and
  `MultiplayerSpawner`.

## 9. Tools and checks

| Check | Command (from `game/`) |
|---|---|
| Format | `gdformat --check scenes tools test` |
| Lint | `gdlint scenes tools test` (settings in `gdlintrc`) |
| Unit tests | `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit` |
| Project-specific checks | `bash tools/lint/conventions.sh` (network boundary, original assets, InputMap) |

- The editor's GDScript warnings `UNSAFE_PROPERTY_ACCESS`, `UNSAFE_METHOD_ACCESS`, `UNSAFE_CAST` and `UNTYPED_DECLARATION`
  are on as warnings. The count only goes down.
- `.import` files are committed with their assets.
- New pure rules get a GUT test in `test/unit/`.
