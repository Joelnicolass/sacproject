class_name OrderCommand
extends Node

## Orders to the selection: a right click orders by what is under the cursor (ground = move, enemy =
## attack, corpse = guard the spot, anything else = guard it), an armed order icon (Ctrl+R / Ctrl+A,
## or the radial menu's entry) takes the left click the same way, retreat calls every creature back
## to the wizard and a formation is stored on the selection. The right button itself belongs to
## OrderRadial.

@export var armed: ArmedCommand
@export var ray: PointerRay
@export var feedback: CommandFeedback

@onready var _log: CommandLog = %Battle
@onready var _selection: RtsSelection = %Selection
@onready var _orders: RtsOrders = %Orders


## The keyboard action has no cursor: it aims through the crosshair, which the third-person
## camera keeps on the wizard's head, so the local wizard is skipped there.
func right_at(screen: Vector2, from_action := false, formation_id := &"") -> void:
	if armed.cancel():
		return
	var body := ray.body_under(screen, from_action)
	if body:
		if PointerRay.is_corpse(body):
			order("guard_area", body.global_position, null, formation_id)
		elif ray.is_enemy(body):
			order("attack", body.global_position, body, formation_id)
		else:
			order("guard", body.global_position, body, formation_id)
		return
	var ground: Variant = ray.ground(screen)
	if ground == null:
		_log.say(Refusal.NO_GROUND)
		return
	order("move", ground, null, formation_id)


## Attack or guard a body; on the ground, advance or guard the spot. A move icon (radial menu)
## goes to the ground point under the cursor.
func icon_at(screen: Vector2) -> void:
	icon_on(ray.body_under(screen, false), ray.ground(screen))


func icon_on(body: Node3D, ground: Variant) -> void:
	var kind := armed.mode
	armed.mode = ""
	if kind == "move":
		var spot: Variant = ground if ground != null else (body.global_position if body else null)
		if spot == null:
			_log.say(Refusal.NO_GROUND)
			return
		order("move", spot, null)
		return
	if body and not PointerRay.is_corpse(body):
		order(kind, body.global_position, body)
		return
	if ground == null:
		_log.say(Refusal.NO_GROUND)
		return
	order("advance" if kind == "attack" else "guard_area", ground, null)


## Calls every creature back to the wizard (Ctrl+Space, the radial menu's retreat).
func retreat() -> void:
	var wizard := ray.wizard()
	if wizard == null:
		_log.say(Refusal.NO_WIZARD)
		return
	_orders.issue(&"retreat", [], wizard.global_position, wizard, ray.camera_yaw())
	_log.say("Retirada")


## What a right click would order where the pointer is: `ground`, `enemy`, `own` (a creature or
## wizard of the local side) or `corpse`. The radial menu shows the matching icon in its center.
func context_kind(screen: Vector2) -> StringName:
	var body := ray.body_under(screen, false)
	if body == null:
		return &"ground"
	if PointerRay.is_corpse(body):
		return &"corpse"
	return &"enemy" if ray.is_enemy(body) else &"own"


## The radial menu chose an order entry: `kind` ("attack", "guard", "move") is given at the screen
## point the menu opened on, as an armed icon clicked there (a body, else the ground spot).
func order_at(kind: String, screen: Vector2) -> void:
	if not CommandFeedback.ORDER_TEXT.has(kind):
		return
	armed.mode = ""
	armed.mode = kind
	icon_at(screen)


## The radial menu chose a formation: the right click of that point (move, attack or guard by what
## is there) given in that formation, in one order. Says the formation's name.
func order_in_formation(id: StringName, screen: Vector2) -> void:
	var formation: RtsFormation = _orders.formations.find(id) if _orders.formations else null
	if formation == null:
		return
	armed.mode = ""
	right_at(screen, false, id)
	_log.say(formation.display_name)


## Alt+1..8: the formation: every selected creature keeps it and nobody moves (the next order uses
## the one most of the group has, Orders). Says the formation's name.
func set_formation(id: StringName) -> void:
	var formation: RtsFormation = _orders.formations.find(id) if _orders.formations else null
	if formation == null:
		return
	var units: Array = _selection.bodies()
	if units.is_empty():
		_log.say(Refusal.NOBODY)
		return
	_orders.issue(RtsOrders.FORMATION, units, Vector3.ZERO, null, ray.camera_yaw(), id)
	_log.say(formation.display_name)


func order(kind: String, point: Vector3, target: Node3D, formation_id := &"") -> void:
	var units: Array = _selection.bodies()
	if units.is_empty():
		_log.say(Refusal.NOBODY)
		return
	feedback.show_ping(point, CommandFeedback.ORDER_TONE.get(kind, OrderMarker.Tone.WHITE))
	_orders.issue(_command_of(kind, target), units, point, target, ray.camera_yaw(), formation_id)
	feedback.say_order(kind)


# The RtsKit command of an order kind of the cursor: an attack on a creature retargets, on anything
# else it does not (OrderLink.attack_command); an advance is the kit's attack_move.
static func _command_of(kind: String, target: Node3D) -> StringName:
	match kind:
		"attack":
			return OrderLink.attack_command(target)
		"advance":
			return &"attack_move"
	return StringName(kind)
