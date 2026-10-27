class_name MpLocalSeat
extends Node

## Who looks at this screen. Drop one in the world and hand it to what shows one player's side (HUD, audio, orders, pause,
## result) with `@export var seat: MpLocalSeat`; a node made at runtime finds it with `MpLocalSeat.of(self)`, or asks only the slot with
## `MpLocalSeat.slot_of(self)` (MpKit.local_slot() where the scene has none). `slot` is the
## seat this PC plays (0 on a dedicated server and on a client not seated yet); `changed(slot)` when it changes.
## Solo, `preview_slot` shows the match as another seat (a quick look at player 2's HUD). Not: who simulates
## (is_multiplayer_authority() / MpKit.is_authority()), who may sit (MpMatchGate).

signal changed(slot: int)

const GROUP := &"mp_local_seat"

## Solo only: look at the match as this seat (0 = your own). Online, the seat the server gave wins.
@export var preview_slot: int = 0

## The seat on this screen.
var slot: int:
	get:
		return _slot

var _slot: int = 0


## The MpLocalSeat of the current scene, or null.
static func of(from: Node) -> MpLocalSeat:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_tree().get_first_node_in_group(GROUP) as MpLocalSeat


## The seat that looks at `from`'s scene: that MpLocalSeat's slot, or MpKit.local_slot() in a scene without one
## (a scene run on its own, a test). For what is made at runtime and only asks "who looks?".
static func slot_of(from: Node) -> int:
	var seat := of(from)
	return seat.slot if seat != null else MpKit.local_slot()


func _enter_tree() -> void:
	add_to_group(GROUP)
	_slot = _current()


func _ready() -> void:
	## The seat can change while the world is paused (a seat given while the match waits).
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var now := _current()
	if now != _slot:
		_slot = now
		changed.emit(_slot)


## True when `other` is the seat on this screen (never for 0).
func is_mine(other: int) -> bool:
	return other > 0 and other == _slot


## True in a networked match (host, client or dedicated); false solo.
func is_online() -> bool:
	return MpKit.is_networked()


func _current() -> int:
	if not MpKit.is_networked() and preview_slot > 0:
		return preview_slot
	return MpKit.local_slot()
