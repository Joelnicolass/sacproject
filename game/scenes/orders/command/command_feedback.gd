class_name CommandFeedback
extends Node

## What the player's commands answer with: the ping a cast or an order leaves at its point (sacengine's command cone,
## local only), the line on %Battle (CommandLog, RFC-025c: the cue flashes `ncst` for a refusal) and the creatures that
## join the selection when they are summoned. It decides no order and no cast.

## state.d:29261-29264: the cone's color by order.
const ORDER_TONE := {
	"attack": OrderMarker.Tone.RED,
	"advance": OrderMarker.Tone.RED,
	"guard": OrderMarker.Tone.BLUE,
	"guard_area": OrderMarker.Tone.BLUE,
}
const ORDER_TEXT := {
	"move": "Orden",
	"attack": "Ataque",
	"guard": "Escolta",
	"guard_area": "Guardia",
	"advance": "Avance",
	"retreat": "Retirada",
}

const _SELECTION := preload("res://scenes/orders/selection.gd")

@onready var _log: CommandLog = %Battle
@onready var _ping: OrderMarker = %Ping
@onready var _selection: _SELECTION = %Selection


func _ready() -> void:
	_log.say("Mago")
	%Units.child_entered_tree.connect(_on_unit_entered)
	_selection.changed.connect(on_selection_changed)
	_connect_soul_messages.call_deferred()


## The one entry for the mark an order (or a cast) leaves at `point`.
## Orders tint it like sacengine (guard blue, attack and advance red, the rest white).
func show_ping(point: Vector3, tone: OrderMarker.Tone = OrderMarker.Tone.WHITE) -> void:
	_ping.play(point, tone)


## The line for an order that was given: its name.
func say_order(kind: String) -> void:
	_log.say(ORDER_TEXT.get(kind, "Orden"))


## What the selection is, as the line on %Battle: a creature's name, «N unidades» or «Mago».
func on_selection_changed(units: Array) -> void:
	if units.size() == 1:
		_log.say((units[0] as UnitBody).display_name())
	elif units.size() > 1:
		_log.say("%d unidades" % units.size())
	else:
		_log.say("Mago")


## «Sin almas» (the drop answer) is a refusal like the others: said on %Battle, it flashes `ncst`.
func _connect_soul_messages() -> void:
	var souls := get_tree().get_first_node_in_group("soul_system") as SoulSystem
	if souls:
		souls.message.connect(_log.say)


func _on_unit_entered(unit: Node) -> void:
	if unit is UnitBody:
		(unit as UnitBody).summoned.connect(_on_unit_summoned.bind(unit), CONNECT_ONE_SHOT)


## sacengine newCreatureAddToSelection: the owner's new creature joins the selection.
func _on_unit_summoned(unit: Node) -> void:
	if is_instance_valid(unit) and (unit as UnitBody).owner_slot == MpKit.local_slot():
		_selection.add_summoned(unit as UnitBody)
