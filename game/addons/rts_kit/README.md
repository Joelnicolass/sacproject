# RtsKit

The command layer of a real-time strategy game, for **2D and 3D**: units, selection and groups, typed orders laid out in formations, the input that gives them (right click by context, armed orders, an optional menu or a command panel), cursor cues and RTS cameras. **No** network, **no** game rules, **no** autoload. It moves no unit and fights no fight: the game does that with the orders the kit hands each unit.

It depends on no other kit. A multiplayer game connects it to MpKit (or any transport) through two calls of its own (see [Network](#network)); a single-player RTS connects nothing.

**New to the kit?** Start with [GUIDE.md](GUIDE.md): a unit, the rig, the ways to give orders, making every part your own, and multiplayer with MpKit, step by step.

## Install

```bash
./install.sh --addon /path/to/godot-project rts_kit
```

Enable the **RtsKit** plugin. Project > Tools > *RtsKit: Add default input actions* writes the default keys into the Input Map so you can rebind them there (without it, `RtsCommandInput` adds the missing ones at runtime).

## One ground for 2D and 3D

The kit thinks in one space (`RtsSpace`): the ground is the XZ plane and Y is up, 3D world coordinates as they are. A 2D world point `(x, y)` is the kit point `(x, 0, y)`: seen from above, a 3D field and a 2D top-down map are the same picture, so one formation, one distance and one yaw serve both. Only the edges convert: `RtsSpace.from_2d` / `to_2d`, `RtsUnitOrder.spot_2d()`.

World units are meters in 3D and **pixels in 2D**. The distances the kit exposes (`RtsOrders.spacing_base`, `max_spacing`, `retarget_range`, `RtsSelection.same_type_radius`, `RtsUnit.size`) default to meters: a 2D game sets them in pixels (the 2D example shows it).

Yaw: forward is `(sin yaw, 0, cos yaw)`, right is `(-cos yaw, 0, sin yaw)`. The cameras and `RtsPointer.camera_yaw()` give the yaw a formation turns by: the view's forward in 3D, the screen's up in 2D.

## The rig

```
Game
├── Units / …                      # your bodies, each with an RtsUnit child
├── Camera                         # RtsCamera3D or RtsCamera2D
├── Command                        # RtsCommandInput: routes keys, shares local_slot
│   ├── Selection                  # RtsSelection
│   ├── Orders                     # RtsOrders: who obeys, formations, slots
│   ├── Pointer                    # RtsPointer: screen -> world
│   ├── State                      # RtsCommandState: what is armed, what was said
│   ├── Armed                      # RtsArmedCommand
│   ├── OrderInput                 # RtsOrderInput: right click, armed clicks, menu entries
│   ├── SelectInput                # RtsSelectInput: left button and box
│   ├── GroupKeys                  # RtsGroupKeys
│   ├── OrderButton                # RtsOrderButton: the right button (+ optional menu)
│   └── Probe                      # RtsTargetProbe: what is under the pointer (cursor, cue)
└── Hud (CanvasLayer)
    ├── View                       # a full-rect Control that takes the world's clicks
    │   └── Box                    # the selection box (any Control)
    ├── CommandCard                # optional: RtsCommandCard, buttons for every order
    ├── RadialMenu                 # optional: rts_radial_menu.tscn (an RtsOrderMenu)
    └── Cue                        # optional: rts_command_cue.tscn
```

Every piece is a node with `@export` sockets; remove one and that command is gone, nothing else breaks. The two examples have the whole rig wired: `examples/skirmish_3d` (with the radial menu) and `examples/skirmish_2d` (no menu at all: a plain right click and the command panel).

## The unit (RtsUnit)

A child of the body (any Node3D or Node2D). The contract between your game and the kit:

| Field | What |
|---|---|
| `owner_slot`, `team` | Whose it is (0 = nobody) and the team it fights for (-1 = its owner's slot) |
| `kind`, `tags` | "Select every one of this kind"; free tags for filters |
| `selectable`, `orderable`, `targetable` | Can its owner pick it, does it take orders now, may others aim at it (all off when it dies) |
| `size` | Its width: formations space units by the widest |
| `center`, `icon`, `formation` | The point a selection box projects; its picture; the formation it keeps |
| `refused` | Command ids it never takes (a pacifist: `[&"attack", &"attack_move"]`) |

A rule of your game goes in a script that `extends RtsUnit` and overrides `accepts(command)`, `is_foe(other)`, `facing_yaw()` or `center_point()`.

**The order queue.** The kit gives orders with `give(order, queue)`; your game listens to `order_started(order, replaced)`, does it, and reports `complete()` or `fail(reason)`; the next queued order (Shift) starts by itself. `order_ended(order, result)` says why one left (`done`, `failed`, `replaced`, `stopped`, `cancelled`). `is_idle()`, `current_order()`, `queued_orders()`. An `RtsUnitOrder` carries the command, its target, the order's point, this unit's slot and facing; `spot()` is where this unit should stand now (it follows a guarded body). `order.is_repeat_of(replaced)` tells a mere refresh (an AI that repeats a follow order).

## Orders (RtsOrders)

`apply(order, from_slot)` is the rules: only `from_slot`'s orderable units that accept the command obey (at most `max_units`); the group stands in the formation most of its units keep (a tie: the first in the catalog); units are spaced by `min(spacing_per_size · widest + spacing_base, max_spacing)`; the slots turn by the order's facing (by the guarded body's for a GUARD order) and units are matched to slots greedily by distance, or row by row for a formation of several rows (no two paths cross). An attack on a unit retargets each unit to the foe nearest its own slot (`retarget_range`, rule: `closest_foe`). A retreat sends the whole side to its anchor (`anchor_for`: by default the unit tagged `anchor`). The command `formation` only stores a formation; nobody moves.

`request(order)` is the local player's: it emits `requested` and hands the order to `send`, which by default is `apply(order, local_slot)`. An AI calls `apply` (or `apply_units`) directly with nodes: nothing is converted.

The kinds of order are data (`RtsCommandType` in an `RtsCommandCatalog`: what they aim at, how a group lays out, who takes them). The kit's catalog has `move`, `attack`, `guard`, `guard_area`, `attack_move`, `retreat`; make your own `.tres` for more (or other names). Formations are data too (`RtsFormation` resources in an `RtsFormationCatalog`: line, flanks, phalanx, semicircle, circle, wedge, skirmish); extend `RtsFormation` for a shape of your own.

### Network

The kit sends nothing. `RtsOrder.to_array()` / `RtsOrder.from_array(data, root)` turn an order into plain data and back (units by NodePath, or by your ids with `id_of` / `node_of`); `from_array` refuses malformed data (layout, types, sizes, NaN). A networked game writes the glue in its own code. With MpKit, through its custom channel (no RPC by hand; it also works offline):

```gdscript
# Every peer: the local player's orders go to the server.
orders.send = func(order: RtsOrder) -> void:
	MpKit.send_custom(&"rts_order", {"order": order.to_array(func(body: Node) -> String: return String(body.name))})

# The server applies them as the player who sent them.
MpKit.custom_received.connect(func(channel: StringName, data: Dictionary, from_peer: int) -> void:
	if channel == &"rts_order" and MpKit.is_authority():
		var slot := MpKit.slot_for_peer(from_peer) if MpKit.is_networked() else MpKit.local_slot()
		orders.apply(RtsOrder.from_array(data.get("order"), self, func(id: String) -> Node: return units_root.get_node_or_null(NodePath(id))), slot))
```

`apply` checks every unit against the sender's slot, so a client can only order what that player owns. The whole path (units spawned by MpKit, their owner, who is "me", a dedicated server): [GUIDE.md › 6](GUIDE.md#6-multiplayer-with-mpkit).

## Input

- **Left button** (`RtsSelectInput`): click selects; Shift toggles; Ctrl / Cmd or a double click selects the same kind nearby; a drag past 3 px draws a box (Shift adds). With something armed the click goes to it. A click on a body that is no own unit emits `clicked_other`; a plain click on the ground clears (`clicked_empty`).
- **Right button** (`RtsOrderButton`): orders by context (`RtsOrderInput.context_orders`: an enemy is attacked, an own or neutral body is guarded, the ground is moved to; `classify` adds your own classes, such as a corpse). With a `menu`, holding the button opens it at the press point and the entry chosen runs there.
- **Keys** (`RtsCommandInput.command_keys`): a command that aims is armed for the next left click, one that does not (retreat) happens now. Alt+1..8 keeps a formation. Groups: Ctrl+N stores (Cmd on macOS, `command_on_macos`), N recalls, Shift+N adds.
- **What waits for a click** (`RtsArmedCommand`): any command of the catalog, or anything your game arms (`arm(&"fireball", payload)`): the click of a game mode comes back as `RtsSelectInput.armed_clicked`.
- **Menus are optional.** Every command UI shows `RtsMenuEntry` items (a command, a formation, or `CUSTOM` for your game) and runs them with `RtsOrderInput.run_entry(entry, screen)`. The kit ships two: `RtsCommandCard` (a panel of buttons with their keys) and `RtsRadialMenu` (rings filled by hand or from the catalogs). Write your own by extending `RtsOrderMenu` (open at a point) or by calling `run_entry` from any button. With no menu the right button is a plain right click.
- **Modal UIs**: a pause menu joins `RtsWorldInput.modal_group` (`rts_modal`) while open and no world input reads anything.
- **Keymap** (`RtsKeymap`): the default actions and keys; `install()` only adds what the project lacks.

## Cameras

`RtsCamera3D` and `RtsCamera2D` share one contract: `yaw`, `is_dragging()` (a click that ends a drag is no order), `focus(point)`, `debug_pointer`. Mode FOLLOW keeps a body in view (3D: third person behind it, turning with the keys, the edges and free look, zooming with the wheel; the eye never goes below the ground, including live ground from `height_at`). Mode FREE is the top-down view: pan with the arrows, the screen edges and a middle drag, turn with Q / E (3D), zoom with the wheel, stay inside `bounds`. `edge_area` limits the edges to the world view; `wheel_blockers` keeps the wheel off a minimap. `RtsCameraEffect` adds a shake on top.

## Cues and pings

`RtsTargetProbe` names what is under the pointer; `RtsCursorSkin` sets the hardware cursor from an `RtsCueSet`; `rts_command_cue.tscn` draws the armed icon at the pointer and flashes refusals with their words (`RtsCueSet.reason_text`). `RtsArmedPreview` asks your rule what a click would answer while something is armed (a building that cannot go there). `RtsPing3D` / `RtsPing2D` mark where an order went.

## Tests

```bash
godot --headless --path rtskit_lab --script res://addons/rts_kit/tests/rts_test_runner.gd
```

`RTSKIT TESTS PASS (n)`. They cover the formations' slots, who obeys, the slot match (greedy and by rows), retarget and retreat, the plain data of an order, the queue, the selection (click, kind, box in 2D and 3D with occlusion, limit, groups), the input on real colliders (pointer, context, armed cycle, box from mouse events, the radial menu, the command panel, the keys, modals), both cameras, and both examples played end to end. `rtskit_lab/` is a project of its own for them; `addons/rts_kit` there is a symlink.

## Not in this version

Unit movement (pathfinding, avoidance), vision and fog of war, a minimap, and combat are the game's for now; RtsKit 0.3–0.5 add movement, vision and the minimap, 0.2 the modern controls (more group and selection keys, Shift queues with waypoints, rally points, patrol, hold position, stances, camera bookmarks, alerts). See `CHANGELOG.md`.
