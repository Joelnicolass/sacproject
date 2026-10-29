class_name RtsOrderInput
extends Node

## Orders to the selection. A right click orders by what is under the pointer: the context of that
## body (RtsUnit relation, or a class of the game through `classify`) picks the command in
## `context_orders` (by default: an enemy is attacked, anything else is guarded, the ground is moved
## to). An armed command takes the left click by what it aims at (RtsCommandType.target): on a body
## when it takes bodies, else on the ground (`ground_orders` turns an attack clicked on the ground into
## an attack-move, a guard into guarding the area). `run_entry` is the one way any command UI (a
## button panel, a radial menu, a game's own) gives what it chose. It reads no buttons itself.

## An order went out at `point` (a ping, a sound). Local only.
signal ordered(command: StringName, point: Vector3, target: Node)
## A CUSTOM entry was chosen (the game's): `screen` is the point it was chosen at, or null.
signal custom_entry(entry: RtsMenuEntry, screen: Variant)

const GROUND := &"ground"

@export var selection: RtsSelection
@export var orders: RtsOrders
@export var pointer: RtsPointer
@export var armed: RtsArmedCommand
@export var state: RtsCommandState
## Context (RtsUnit.OWN / ALLY / NEUTRAL / ENEMY, RtsPointer.OTHER, `ground`, or a class of the game)
## -> command id.
@export var context_orders: Dictionary[StringName, StringName] = {
	&"own": &"guard",
	&"ally": &"guard",
	&"neutral": &"guard",
	&"enemy": &"attack",
	&"other": &"guard",
	&"ground": &"move",
}
## Contexts ordered at the body's position with no target (a corpse: guard the spot).
@export var point_contexts: Array[StringName] = []
## A command that aims at bodies, clicked on the ground: command -> the ground command.
@export var ground_orders: Dictionary[StringName, StringName] = {
	&"attack": &"attack_move",
	&"guard": &"guard_area",
}
## Say each order's name on the state (off: only refusals are said).
@export var say_orders := true

## A class of the game for a body: `func(body: Node) -> StringName` (&"" = none, the kit's relation
## applies). A game adds its own targets this way (a corpse, a soul).
var classify: Callable


## The order of a right click at `screen`. `from_action`: a keyboard action aiming at the screen
## middle, which sees through the player's own anchor (a hero the camera follows).
func right_at(screen: Vector2, from_action := false, formation := &"") -> void:
	if armed and armed.cancel():
		return
	var skip: Array = []
	if from_action and orders:
		var own: Variant = orders.anchor_for.call(orders.local_slot)
		if own is Node:
			skip.append(own)
	var body := pointer.body_under(screen, skip)
	if body:
		var context := context_of(body)
		var command: StringName = context_orders.get(context, &"")
		if command == &"":
			return
		if point_contexts.has(context):
			give(command, RtsSpace.position_of(body), null, formation)
		else:
			give(command, RtsSpace.position_of(body), body, formation)
		return
	var ground: Variant = pointer.ground_at(screen)
	if ground == null:
		_say(RtsRefusal.NO_GROUND)
		return
	give(context_orders.get(GROUND, &"move"), ground, null, formation)


## What `body` is for an order: the game's class, else its relation to the local player.
func context_of(body: Node) -> StringName:
	if classify.is_valid():
		var game_class: Variant = classify.call(body)
		if game_class is StringName and game_class != &"":
			return game_class
		if game_class is String and not (game_class as String).is_empty():
			return StringName(game_class)
	return pointer.relation(body)


## What a right click would order at `screen`: `ground` or the context of the body there (a menu may
## show it).
func context_kind(screen: Vector2) -> StringName:
	var body := pointer.body_under(screen)
	return GROUND if body == null else context_of(body)


## The armed command takes a click at `screen`.
func icon_at(screen: Vector2) -> void:
	icon_on(pointer.body_under(screen), pointer.ground_at(screen))


## The armed command lands on `body` (or null) with `ground` (a kit point, or null) under it.
func icon_on(body: Node, ground: Variant) -> void:
	var command := armed.mode if armed else &""
	if armed:
		armed.mode = &""
	aim(command, body, ground)


## Command `command` aimed at `body` (or null) over `ground` (a kit point, or null): on the body when
## the command takes bodies, else at the ground (or the body's place when the pointer has no ground).
func aim(command: StringName, body: Node, ground: Variant) -> void:
	var type := _type(command)
	if type == null:
		return
	var takes_body := (
		type.target == RtsCommandType.Target.BODY or type.target == RtsCommandType.Target.POINT_OR_BODY
	)
	if body and takes_body and not point_contexts.has(context_of(body)):
		give(command, RtsSpace.position_of(body), body)
		return
	var at: Variant = ground
	if at == null and body and type.target == RtsCommandType.Target.POINT:
		at = RtsSpace.position_of(body)
	if at == null:
		_say(RtsRefusal.NO_GROUND)
		return
	var on_ground: StringName = ground_orders.get(command, &"")
	if on_ground == &"":
		if type.target == RtsCommandType.Target.BODY:
			_say(RtsRefusal.NO_TARGET)
			return
		on_ground = command
	give(on_ground, at, null)


## Runs what a command UI chose. `screen` is where it was chosen (a menu opened at that point), or
## null (a button): a command that aims is then armed for the next left click.
func run_entry(entry: RtsMenuEntry, screen: Variant = null) -> void:
	if entry == null:
		return
	match entry.kind:
		RtsMenuEntry.Kind.COMMAND:
			run_command(entry.command, screen)
		RtsMenuEntry.Kind.FORMATION:
			if entry.formation == null:
				return
			if screen is Vector2:
				order_in_formation(entry.formation.id, screen)
			else:
				set_formation(entry.formation.id)
		RtsMenuEntry.Kind.CUSTOM:
			custom_entry.emit(entry, screen)


## Command `command` from a key, a button or a menu: one that aims at nothing (retreat) happens now;
## one that aims is given at `screen` when there is one, else armed for the next left click.
func run_command(command: StringName, screen: Variant = null) -> void:
	var type := _type(command)
	if type == null:
		return
	if type.target == RtsCommandType.Target.NONE:
		if armed:
			armed.mode = &""
		if type.to_anchor:
			retreat(command)
		else:
			give(command, Vector3.ZERO, null)
		return
	if screen is Vector2:
		if armed:
			armed.mode = &""
		aim(command, pointer.body_under(screen), pointer.ground_at(screen))
	elif armed:
		armed.arm_order(command, true)


## Sends every unit of the side to its anchor (RtsOrders.anchor_for).
func retreat(command := &"retreat") -> void:
	var anchor: Variant = orders.anchor_for.call(orders.local_slot)
	if not anchor is Node:
		_say(RtsRefusal.NO_ANCHOR)
		return
	var target := anchor as Node
	var point := RtsSpace.position_of(target)
	orders.request(RtsOrder.make(command, [], point, target, pointer.camera_yaw()))
	ordered.emit(command, point, target)
	_say_order(command)


## The right click of `screen` in formation `id`, in one order.
func order_in_formation(id: StringName, screen: Vector2) -> void:
	var formation := orders.formations.find(id) if orders and orders.formations else null
	if formation == null:
		return
	if armed:
		armed.mode = &""
	right_at(screen, false, id)
	_say(tr(formation.display_name))


## Every selected unit keeps formation `id`; nobody moves (the next order uses the one most of the
## group keeps).
func set_formation(id: StringName) -> void:
	var formation := orders.formations.find(id) if orders and orders.formations else null
	if formation == null:
		return
	var units := selection.units()
	if units.is_empty():
		_say(RtsRefusal.NOBODY)
		return
	orders.request(RtsOrder.make(RtsOrders.FORMATION, units, Vector3.ZERO, null, 0.0, id))
	_say(tr(formation.display_name))


## The selection gets `command` at `point` (on `target`, or none).
func give(command: StringName, point: Vector3, target: Node, formation := &"") -> void:
	var units := selection.units()
	if units.is_empty():
		_say(RtsRefusal.NOBODY)
		return
	orders.request(
		RtsOrder.make(command, units, point, target, pointer.camera_yaw(), formation)
	)
	ordered.emit(command, point, target)
	_say_order(command)


func _type(command: StringName) -> RtsCommandType:
	return orders.commands.find(command) if orders and orders.commands else null


func _say_order(command: StringName) -> void:
	if not say_orders:
		return
	var type := _type(command)
	_say(tr(type.display_name) if type and not type.display_name.is_empty() else String(command))


func _say(text: String) -> void:
	if state:
		state.say(text)
