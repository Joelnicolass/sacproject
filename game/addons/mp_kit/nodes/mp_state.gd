@tool
class_name MpState
extends Node

## Drop one in the world for the values every player must see: score, timer, round. The server writes them with
## set_value / add; every peer gets `changed(key, value)` (or `watch(key, callback)`: the current value, then each change), and a
## player who joins or comes back gets the current ones.
## Find it from anywhere in the world with `MpState.of(self)`. In solo it is a plain Dictionary.
## Not: per-actor data (MpActor sync), one-off effects (MpActor.to_all), game rules.

signal changed(key: StringName, value: Variant)

const GROUP := &"mp_state"
const SYNC_NAME := "MpSync"

## Current values (fill keys and starting values in the inspector if you like).
@export var values: Dictionary = {}:
	set(next):
		var before := values
		values = next
		if Engine.is_editor_hint():
			return
		for key in next:
			if not before.has(key) or before[key] != next[key]:
				changed.emit(key, next[key])
		for key in before:
			if not next.has(key):
				changed.emit(key, null)


## The MpState of the current scene (the one named `state_name` if there are several), or null.
static func of(from: Node, state_name: StringName = &"") -> MpState:
	if from == null or not from.is_inside_tree():
		return null
	for node in from.get_tree().get_nodes_in_group(GROUP):
		if state_name == &"" or node.name == state_name:
			return node as MpState
	return null


func _enter_tree() -> void:
	add_to_group(GROUP)
	if Engine.is_editor_hint():
		_rebuild_sync.call_deferred()


func get_value(key: StringName, default: Variant = null) -> Variant:
	return values.get(key, default)


## Every peer: calls `on_value(value)` now with the current value of `key` (`default` while it has none), then on every change
## of that key. Whoever joins or comes back gets the current value first, whatever order the nodes start in. Returns a
## handle for unwatch(); the watch also ends with this node.
func watch(key: StringName, on_value: Callable, default: Variant = null) -> Callable:
	var relay := func(changed_key: StringName, value: Variant) -> void:
		if changed_key == key and on_value.is_valid():
			on_value.call(default if value == null else value)
	changed.connect(relay)
	on_value.call(values.get(key, default))
	return relay


## Stops a watch (the handle watch() returned).
func unwatch(handle: Callable) -> void:
	if changed.is_connected(handle):
		changed.disconnect(handle)


## Server (or solo) only. Every peer gets `changed`.
func set_value(key: StringName, value: Variant) -> void:
	if not MpKit.is_authority():
		push_warning("MpState '%s': set_value(%s) only runs on the server" % [name, key])
		return
	if values.has(key) and values[key] == value:
		return
	var next := values.duplicate(true)
	next[key] = value
	values = next


## Server (or solo) only: adds `amount` to a number (missing = 0).
func add(key: StringName, amount: float = 1) -> void:
	var now: Variant = values.get(key, 0)
	if typeof(now) == TYPE_INT and amount == int(amount):
		set_value(key, int(now) + int(amount))
	else:
		set_value(key, float(now) + amount)


func _rebuild_sync() -> void:
	var scene := get_tree().edited_scene_root if is_inside_tree() else null
	if scene == null or owner != scene:
		return
	MpSyncBuilder.ensure(self, SYNC_NAME, NodePath(".."), PackedStringArray(["values"]), PackedStringArray(), scene)
	update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	if get_node_or_null(SYNC_NAME) == null:
		return PackedStringArray(["Save the scene: the %s child is built in the editor." % SYNC_NAME])
	return PackedStringArray()
