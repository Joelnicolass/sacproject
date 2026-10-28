# RtsKit guide: your RTS, step by step

For someone who has never used the kit. It walks from an empty battle scene to units you select and order, then shows how to make every part your game's own, and finally how to play it over the network with MpKit. The reference for each piece is [README.md](README.md); the API, [skills/godot-rts-kit/api.md](../../skills/godot-rts-kit/api.md).

**The one idea to keep:** RtsKit **commands**, your game **acts**. The kit decides who may be selected, who obeys an order, the formation and where each unit stands. Your game walks the unit there, fights, dies. The kit hands each unit an `RtsUnitOrder`; your unit says when it is done.

- [1. Install](#1-install)
- [2. A unit](#2-a-unit)
- [3. The command rig](#3-the-command-rig)
- [4. How the player gives orders](#4-how-the-player-gives-orders)
- [5. Make it yours](#5-make-it-yours)
- [6. Multiplayer with MpKit](#6-multiplayer-with-mpkit)
- [7. Checklist](#7-checklist)

## 1. Install

```bash
./install.sh --addon /path/to/your-godot-project rts_kit
```

1. Project > Project Settings > Plugins: enable **RtsKit**.
2. Project > Tools > **RtsKit: Add default input actions**. The kit's actions appear in the Input Map, where you can rebind them (section 5.8).
3. Open `addons/rts_kit/examples/skirmish_3d/skirmish_3d.tscn` (or `skirmish_2d`) and press F6. Everything below is in those scenes.

## 2. A unit

A unit is your own scene (a `CharacterBody3D`, a `CharacterBody2D`, any body) with one **RtsUnit** child.

```
Soldier (CharacterBody3D)        # your body, your script
├── CollisionShape3D             # on the units' layer (layer 2 by default): clicks find it
├── MeshInstance3D
├── SelectionRing                # anything you show while selected
├── NavigationAgent3D            # your movement
└── RtsUnit                      # owner_slot, kind, size…
```

In the inspector of `RtsUnit`:

| Field | Set it to |
|---|---|
| `owner_slot` | The player who owns it (1 in a single-player game; 0 = nobody) |
| `kind` | Its type, e.g. `soldier`: Ctrl / Cmd + click selects every `soldier` nearby |
| `size` | Its width in world units: formations space by the widest unit |
| `center` | Optional: a `Marker3D` at the middle of the body, for the selection box |

Then **your unit script** does what the kit cannot: it walks, fights and reports.

```gdscript
# soldier.gd — your game's code
extends CharacterBody3D

@export var speed := 6.0

var order: RtsUnitOrder

@onready var unit: RtsUnit = $RtsUnit
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var ring: Node3D = $SelectionRing


func _ready() -> void:
	unit.order_started.connect(_on_order_started)
	unit.order_ended.connect(_on_order_ended)
	unit.selected_changed.connect(func(on: bool) -> void: ring.visible = on)


func _on_order_started(next: RtsUnitOrder, _replaced: RtsUnitOrder) -> void:
	order = next


func _on_order_ended(old: RtsUnitOrder, _result: StringName) -> void:
	if old == order:
		order = null


func _physics_process(_delta: float) -> void:
	if order == null:
		return
	# spot() is this unit's place in the formation; it follows a guarded body that walks.
	agent.target_position = order.spot()
	if agent.is_navigation_finished():
		if order.type.ends_on_its_own:
			unit.complete()   # the next queued order (if any) starts by itself
		return
	var next := agent.get_next_path_position()
	velocity = (next - global_position).normalized() * speed
	move_and_slide()


func die() -> void:
	# A dead unit leaves every selection and group by itself.
	unit.selectable = false
	unit.orderable = false
	unit.targetable = false
```

- `order.command` says which order it is (`move`, `attack`, `guard`…); `order.target` is the body to act on (an enemy, a friend to guard) or null. A real game chases and hits `order.target` on `attack`, and fights what comes near on `guard_area` / `attack_move`; the example's `RtsExampleWalker` only walks.
- `ends_on_its_own` is on for `move` and `attack` (report `complete()` when there / when the target is dead) and off for `guard`, `guard_area`, `attack_move`, `retreat` (they stay until another order replaces them).
- Something went wrong (no path)? `unit.fail(&"no_path")`.

**2D** is the same with a `CharacterBody2D`, a `CollisionShape2D` on layer 2 and `order.spot_2d()`. In 2D, world units are **pixels**: set `RtsUnit.size` in pixels (section 5.6).

## 3. The command rig

The rig is a set of small nodes; each does one thing and points at the others through `@export` sockets. The fastest way: open the example, select the `Command` and `Hud` nodes, copy them into your battle scene, and fix the sockets that point at the camera.

```
Battle (Node3D)
├── Units                          # your units
├── Camera                         # RtsCamera3D (2D: RtsCamera2D)
├── Command                        # RtsCommandInput
│   ├── Selection                  # RtsSelection
│   ├── Orders                     # RtsOrders
│   ├── Pointer                    # RtsPointer
│   ├── State                      # RtsCommandState
│   ├── Armed                      # RtsArmedCommand
│   ├── OrderInput                 # RtsOrderInput
│   ├── SelectInput                # RtsSelectInput
│   ├── GroupKeys                  # RtsGroupKeys
│   ├── OrderButton                # RtsOrderButton
│   └── Probe                      # RtsTargetProbe (for the cursor; optional)
└── Hud (CanvasLayer)
    └── View                       # Control, full rect: takes the world's clicks
        └── Box                    # Panel: the selection box while dragging
```

The sockets, piece by piece:

| Node | Sockets |
|---|---|
| `Command` | `selection`, `orders`, `pointer`, `armed`, `state`, `order_input`, `select_input`, `group_keys`, `order_button` (its children) |
| `Selection` | `box` = `Hud/View/Box` |
| `Pointer` | `camera` = `Camera`; `ground` = your ground body (so buildings on the same layer are not ground) |
| `Armed` | `state` |
| `OrderInput` | `selection`, `orders`, `pointer`, `armed`, `state` |
| `SelectInput` | `view` = `Hud/View`, `selection`, `pointer`, `armed`, `order_input` |
| `GroupKeys` | `selection` |
| `OrderButton` | `view` = `Hud/View`, `order_input`, `pointer` (and `menu`, section 4) |
| `Camera` | `ground`, `edge_area` = `Hud/View` |

`Hud/View` is what tells "a click on the world" from "a click on the HUD": everything of the HUD above it keeps its own clicks. Leave its mouse filter on *Stop*.

Physics layers: by default the ground is layer 1 and units are layer 2 (`RtsPointer.ground_mask`, `unit_mask`, `pick_mask`). Change them there if your project uses others.

**Who is "me".** `RtsCommandInput.local_slot` is the player at this screen (1 by default) and it hands that value to the selection, the orders and the pointer. Only that slot's units can be selected and ordered.

Press F6: drag a box over your units, right click on the ground, and they walk there in a line.

## 4. How the player gives orders

Out of the box, with no menu at all:

- **Right click**: on the ground, move; on an enemy, attack; on an own or neutral body, guard it.
- **Keys**: A / G / M arm attack / guard / move for the next left click; R retreats; Alt+1..8 keep a formation; Ctrl+1..0 (Cmd on macOS) store a group, 1..0 recall it, Shift+1..0 add to it.

On top of that, any command UI you want. They all show the same entries (`RtsMenuEntry`: a command, a formation, or something of yours) and run them the same way (`RtsOrderInput.run_entry`).

**A command panel** (buttons, the classic RTS way). Add a `GridContainer` to the HUD with the script `rts_command_card.gd`; sockets `order_input` and `command_input` (`Command`, for the keys it shows). It builds one button per command and per formation. A button that aims (attack) arms it for the next left click; retreat happens at once; a formation is kept by the selection. `skirmish_2d` has one.

**The radial menu** (hold the right button). Instance `addons/rts_kit/ui/radial/rts_radial_menu.tscn` under the HUD and set `OrderButton.menu` to it. Holding the right button 0.25 s opens it where you pressed; what you release on runs at that point; the middle cancels. Its layout is a list of rings: by default one with every command and one with every formation; edit `rts_default_layout.tres` (or a copy) to choose. `skirmish_3d` has one.

**Your own.** A button anywhere: `button.pressed.connect(func() -> void: order_input.run_entry(entry))`. A menu that opens at a point (a list, a pie of your own): a script that `extends RtsOrderMenu` and overrides `open_at`, `point_at`, `confirm`, `cancel`, `is_open`; set it as `OrderButton.menu`.

Remove any of them and the right click and the keys keep working.

## 5. Make it yours

### 5.1 Your kinds of order

Orders are data. Make a new **RtsCommandCatalog** resource, add **RtsCommandType** items, and set it as `Orders.commands` (and `Armed.commands`). Start from a copy of `addons/rts_kit/commands/commands.tres`. A "hold position" order, for example:

| Field | Value |
|---|---|
| `id` | `hold` |
| `display_name` | `Hold position` |
| `target` | `NONE` (it aims at nothing: it happens at once) |
| `uses_formation` | off (each unit holds where it is) |
| `ends_on_its_own` | off |

Give it a key: add an action `my_hold` to the Input Map and `my_hold → hold` to `Command.command_keys`. Your unit script handles `order.command == &"hold"` (stop, fight only what comes in range). It shows up in the command panel and the radial menu by itself.

### 5.2 Your formations

Extend `RtsFormation` and return the slots (right, forward) for `count` units:

```gdscript
# column_formation.gd — single file behind the point
class_name ColumnFormation
extends RtsFormation


func slots(count: int, spacing: float, _target_distance: float, _role: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in count:
		result.append(Vector2(0.0, -i * spacing))
	return result
```

Create a `ColumnFormation` resource (id `column`, a name), add it to a copy of `addons/rts_kit/orders/formations/formations.tres`, and set that as `Orders.formations`. The first formation of the catalog wins ties; Alt+N picks the Nth.

### 5.3 Rules of your units

A script that extends `RtsUnit` (use it instead of `RtsUnit` on your units):

```gdscript
# my_unit.gd
class_name MyUnit
extends RtsUnit

@export var aggressiveness := 1.0


## Pacifists move but never attack.
func accepts(command: StringName) -> bool:
	if aggressiveness <= 0.0 and command in [&"attack", &"attack_move"]:
		return false
	return super.accepts(command)


## Neutral monsters bite everybody.
func is_foe(other: RtsUnit) -> bool:
	return team_id() == 0 or super.is_foe(other)
```

For a pacifist only, no script is needed: `refused = [attack, attack_move]` in the inspector.

### 5.4 What a right click means

`OrderInput.context_orders` maps what is under the pointer to a command: `enemy`, `own`, `ally`, `neutral`, `other` (a body that is no unit) and `ground`. Add classes of your game with `classify`:

```gdscript
# in your battle script
order_input.classify = func(body: Node) -> StringName:
	return &"corpse" if body.is_in_group(&"corpse") else &""
order_input.context_orders[&"corpse"] = &"guard_area"
order_input.point_contexts.append(&"corpse")   # order at its spot, not on the body
```

### 5.5 Spells, buildings and other things you arm

```gdscript
@onready var armed: RtsArmedCommand = $Command/Armed
@onready var pointer: RtsPointer = $Command/Pointer


func _on_fireball_button() -> void:
	armed.arm(&"fireball", fireball_data)   # the cursor shows it; a right click cancels it


func _ready() -> void:
	$Command/SelectInput.armed_clicked.connect(_on_armed_click)


func _on_armed_click(mode: StringName, screen: Vector2) -> void:
	if mode != &"fireball":
		return
	var point: Variant = pointer.ground_at(screen)
	if point == null:
		$Command/State.say(RtsRefusal.NO_GROUND)   # flashes the refused cue
		return
	cast_fireball(point, armed.payload)
	armed.mode = &""   # or keep it armed for another cast
```

While it is armed, an **RtsArmedPreview** (`answer` callable) can ask your rule what a click would answer, so the cursor turns "blocked" before the player clicks.

### 5.6 2D: distances in pixels

The kit's distances default to meters. In a 2D game set, in pixels: `Orders.spacing_base`, `max_spacing`, `retarget_range`, `Selection.same_type_radius` and each `RtsUnit.size`. `skirmish_2d` uses 8, 120, 1200, 600 and about 40.

### 5.7 Camera

- A free top-down view: `RtsCamera3D.mode = FREE`, set `bounds` to your map, `free_min_distance` / `free_max_distance` for the zoom.
- A hero RTS: `mode = FOLLOW` and `set_follow(hero)`.
- Both: switch `mode` at runtime (the examples do it with F).
- 2D: `RtsCamera2D` with `bounds`, `min_zoom`, `max_zoom`; `can_turn` to let Q / E turn the view.
- A shake: a script that extends `RtsCameraEffect` as `effect`.

### 5.8 Keys

Rebind any action in Project Settings > Input Map: the kit only adds the ones that are missing. The group-store keys use Cmd on macOS; set `Command.command_on_macos = false` for Ctrl everywhere (only for the defaults the kit adds).

### 5.9 Menus, pause and the HUD

A pause or options screen joins the group `rts_modal` while open (`add_to_group(RtsWorldInput.modal_group)`): no click, key, edge or wheel reaches the world. A HUD panel above `Hud/View` keeps its clicks.

### 5.10 The cursor and the words

Make an **RtsCueSet** resource: the cursor pictures by what is under the pointer, the icon of each armed order, the refused icon and the words of each refusal (`reason_texts`, translated with `tr`). Use it in `State.cues`, `Cue.cues` and an `RtsCursorSkin`.

## 6. Multiplayer with MpKit

RtsKit has no network and never names MpKit; a few lines of **your** code connect them. This section assumes a world that already runs with MpKit (MpKit's `QUICKSTART.md`: an `MpGame`, a boot with `MpFlow`, a world with `MpWorld`).

**The model.** The server runs the rules: it applies orders and moves units. A client sends its orders to the server and sees the units move through MpKit's sync. The server checks every unit of an order against the slot of the player who sent it, so a client can only order its own units.

### 6.1 Units that every peer sees

In the unit scene, add an **MpActor** next to the `RtsUnit`: sync position and rotation, and in *Extra* the unit's flags clients need:

```
RtsUnit:selectable
RtsUnit:targetable
```

In the unit script, take the owner from the MpActor (the spawn brings it to every peer before `_ready`) and run the unit's logic only on the server:

```gdscript
@onready var net: MpActor = $MpActor


func _ready() -> void:
	unit.owner_slot = net.owner_slot
	# … the rest of section 2


func _physics_process(_delta: float) -> void:
	if not net.is_authority():   # clients only draw what the server sends
		return
	# … the movement of section 2
```

Make the units appear on the server with an **MpSpawner** (MpKit `GUIDE.md` 7.2): an empty `Units` node, an `MpSpawner` with `spawn_path = ../Units` and your unit scene in **Extra Scenes**. Then, on the server:

```gdscript
const SOLDIER := preload("res://units/soldier.tscn")


func _spawn_armies() -> void:
	if not MpKit.is_authority():
		return
	var spawner := $UnitSpawner as MpSpawner
	for slot in MpKit.occupied_slots():
		# MpWorld's SpawnPoints: one marker per seat.
		var start: Vector3 = ($MpWorld/SpawnPoints.get_child(slot - 1) as Node3D).global_position
		for i in 6:
			spawner.spawn_actor(SOLDIER, {"position": start + Vector3(i * 2.0, 0, 0)}, slot)
```

### 6.2 Orders over the network

One node of your game sends the local player's orders through MpKit's custom channel and applies the ones that arrive on the server. No RPC is written by hand, and the same code works in a single-player match (MpKit then delivers the message locally):

```gdscript
# rts_mp_glue.gd — your game's code, next to Command
extends Node

const CHANNEL := &"rts_order"

@export var orders: RtsOrders
## Where the units are (the MpSpawner's spawn_path): an order names units by their node name.
@export var units_root: Node


func _ready() -> void:
	MpKit.custom_received.connect(_on_custom)
	orders.send = func(order: RtsOrder) -> void:
		MpKit.send_custom(CHANNEL, {"order": order.to_array(_id_of)})


func _on_custom(channel: StringName, data: Dictionary, from_peer: int) -> void:
	if channel != CHANNEL or not MpKit.is_authority():
		return
	var slot := MpKit.slot_for_peer(from_peer) if MpKit.is_networked() else MpKit.local_slot()
	orders.apply(RtsOrder.from_array(data.get("order"), self, _node_of), slot)


func _id_of(body: Node) -> String:
	return String(body.name)


func _node_of(id: String) -> Node:
	return units_root.get_node_or_null(NodePath(id))
```

- If your `MpGame` lists `custom_channels`, add `rts_order` there (an empty list allows every channel).
- Units travel by node name: a few bytes each. MpKit refuses a custom message bigger than `custom_max_bytes` (8 KB) and more than about 30 per second per player: hundreds of units per order fit.
- `RtsOrder.from_array` refuses malformed data, and `apply` refuses units of another slot: a modified client cannot order what is not its own.

### 6.3 Who is "me"

The player at this screen is MpKit's local slot. In your battle script:

```gdscript
func _ready() -> void:
	$Command.local_slot = MpKit.local_slot()
	if MpKit.is_dedicated():
		# A dedicated server has no player: no selection, no HUD.
		$Command.process_mode = Node.PROCESS_MODE_DISABLED
		$Hud.visible = false
```

Teams (2 vs 2): set `RtsUnit.team` on the units and `Command.local_team` for the player.

### 6.4 What stays local

The selection, the groups, the cursor, the menus, the camera and the pings live on each player's machine: nothing of that travels. Only orders do. A formation a player keeps (Alt+N) is an order too (`formation`), so the server knows it.

## 7. Checklist

- [ ] Every unit has an `RtsUnit` with `owner_slot`, `kind` and `size`; dead units turn `selectable`, `orderable` and `targetable` off.
- [ ] Your unit script listens to `order_started` and calls `complete()` / `fail()`.
- [ ] The rig's sockets are set; `Hud/View` covers the world; the ground and units are on the pointer's layers.
- [ ] F6: a box selects your units only, a right click on the ground moves them in formation, on an enemy they attack, Ctrl/Cmd+1 then 1 recalls the group, Alt+N keeps a formation.
- [ ] 2D: distances in pixels.
- [ ] Networked: units are spawned by an `MpSpawner` with the owner's slot; the glue node is in the world; `local_slot` comes from MpKit; the unit logic runs only where `net.is_authority()`.
