@tool
class_name CommandVoice
extends Node

## RFC-052 052e (F364): the creatures answer the local player (sacengine speakCommand / responseSoundType), on one voice
## channel of their own (an AudioStreamPlayer; the newest answer cuts the one speaking).
## - Selecting: Selection.changed -> the first selected creature says `selected` (the original's `Xcnt`). Selecting the same
##   creature again and again: past `annoy_after` times in a row it says `annoyed` instead (`Xann`), when its set has one.
##   A selection that only shrank (a creature died, was dropped) says nothing.
## - Ordering: Orders.requested(units, command) (the local order path, before it is sent) -> the first one says
##   `order_events[command]`: `ack` for move and guard (`Xcnf`), `attack_ack` for attack and advance (`Xcat`). An order
##   starts the count of `annoyed` again.
## - Each kind keeps its cooldown (`cooldown_s` selections, `ack_cooldown_s` orders): clicking fast does not chain voices.
## The cue is the creature's own set (SoundLibrary.creature of its tag, with the fallback chain), then `aliases`. No set or no
## cue: silence, no log entry. Only the local player's (Selection and Orders.request are local). With the AudioGate closed
## (dedicated, room server, headless) it creates nothing. No RPC, nothing written to the simulation.

## Emits `changed(units: Array)` (scenes/orders/selection.gd, %Selection).
@export var selection: Node:
	set(value):
		selection = value
		update_configuration_warnings()
## Emits `requested(units: Array, command: String)` (scenes/orders/orders.gd, %Orders).
@export var orders: Node:
	set(value):
		orders = value
		update_configuration_warnings()
## Game seconds between two selection voices.
@export_range(0.0, 5.0, 0.05, "suffix:s") var cooldown_s := 0.5
## Game seconds between two order voices.
@export_range(0.0, 5.0, 0.05, "suffix:s") var ack_cooldown_s := 0.3
## The same creature selected more than this many times in a row says `annoyed` (sacengine: lastSelected > 3).
@export_range(1, 20) var annoy_after := 3
## Orders command -> the event the first creature answers with. A command that is not here says nothing (retreat, formation).
@export var order_events: Dictionary[String, StringName] = {
	"move": SoundEvent.ACK,
	"guard": SoundEvent.ACK,
	"guard_area": SoundEvent.ACK,
	"attack": SoundEvent.ATTACK_ACK,
	"advance": SoundEvent.ATTACK_ACK,
}
## Event -> other keys tried in order in the creature's set when it has no cue for the event (the baked sets keep the
## original's codes for the events that had none when they were baked).
@export var aliases: Dictionary[StringName, PackedStringArray] = {
	SoundEvent.ATTACK_ACK: PackedStringArray(["Xcat", "ack"]),
	SoundEvent.ANNOYED: PackedStringArray(["Xann"]),
}

var _open := false
var _player: AudioStreamPlayer
var _last_size := 0
var _last_unit_id := 0
var _count := 0
var _last_select_s := -INF
var _last_ack_s := -INF


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_open = AudioGate.is_open()
	if not _open:
		return
	_player = AudioStreamPlayer.new()
	_player.name = "Channel"
	add_child(_player)
	if selection != null and selection.has_signal("changed"):
		selection.connect("changed", _on_selection_changed)
	if orders != null and orders.has_signal("requested"):
		orders.connect("requested", _on_orders_requested)


## The cue `unit` answers `event` with, or null (no set, no cue: silence).
func cue_for(unit: Node, event: StringName) -> SoundCue:
	if not _open or unit == null or not is_instance_valid(unit):
		return null
	var own := SoundLibrary.creature(StringName(str(unit.get("creature_tag"))))
	if own == null:
		return null
	var keys: Array[StringName] = [event]
	for alias in aliases.get(event, PackedStringArray()):
		keys.append(StringName(alias))
	for key in keys:
		var cue := own.cue(key)
		if cue != null and not cue.is_silent():
			return cue
	return null


## `unit` says `event` on the channel now (cutting the line speaking). False when it is silent or was dropped.
func speak(unit: Node, event: StringName) -> bool:
	var cue := cue_for(unit, event)
	if cue == null:
		return false
	return SoundBus.play_on(_player, cue, StringName(unit.name), event)


## The event the next selection of `unit` would say (`annoyed` past the count, when there is a cue for it).
func selection_event(unit: Node) -> StringName:
	var count := _count + 1 if unit != null and unit.get_instance_id() == _last_unit_id else 1
	if count > annoy_after and cue_for(unit, SoundEvent.ANNOYED) != null:
		return SoundEvent.ANNOYED
	return SoundEvent.SELECTED


func _on_selection_changed(units: Array) -> void:
	var shrank := units.size() < _last_size
	_last_size = units.size()
	if shrank or units.is_empty() or not is_instance_valid(units[0]):
		return
	var first: Node = units[0]
	var event := selection_event(first)
	var id := first.get_instance_id()
	_count = _count + 1 if id == _last_unit_id else 1
	_last_unit_id = id
	var now := BodySounds.game_seconds()
	if now - _last_select_s < cooldown_s:
		return
	if speak(first, event):
		_last_select_s = now


func _on_orders_requested(units: Array, command: String) -> void:
	var event: StringName = order_events.get(command, &"")
	if event.is_empty() or units.is_empty() or not is_instance_valid(units[0]):
		return
	_count = 0
	var now := BodySounds.game_seconds()
	if now - _last_ack_s < ack_cooldown_s:
		return
	if speak(units[0], event):
		_last_ack_s = now


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if selection == null:
		out.append("Asigná `selection` (%Selection): sin ella elegir no habla.")
	if orders == null:
		out.append("Asigná `orders` (%Orders): sin él las órdenes no se acusan.")
	return out
