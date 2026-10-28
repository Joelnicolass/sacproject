class_name AbilityCommand
extends Node

## The selection's active ability. One that needs a target (its target flags are not 0) arms the next left click; any
## other is used at once with no target. The click (screen or minimap) looks for a body, and for souls and corpses when
## the ability aims at them. Every selected creature whose active ability is the armed one gets the order.

const _SELECTION := preload("res://scenes/orders/selection.gd")

@export var armed: ArmedCommand
@export var ray: PointerRay
@export var feedback: CommandFeedback
## The roster whose ability icon uses the ability. Empty (the roster was removed): only the keys use it.
@export var roster: SelectionRoster

@onready var _log: CommandLog = %Battle
@onready var _selection: _SELECTION = %Selection


func _ready() -> void:
	if roster != null:
		roster.ability_pressed.connect(use)


## Ctrl+Q / Shift+B and the roster's ability icon.
func use() -> void:
	var ability := _selection.ability()
	if ability == null:
		return
	if ability.needs_target():
		armed.mode = "ability"
		armed.ability = ability
		_log.arm("ability", ability.icon, TargetProbe.ORDER_TARGETS)
		return
	_apply(ability, null, null)


func click_at(screen: Vector2) -> void:
	var body := ray.body_under(screen, false)
	# An ability that aims at souls or corpses (Breath of life) looks for them after the living body.
	if body == null and _aims_at_dead(armed.ability):
		body = ray.soul_under(screen)
		if body == null:
			body = ray.corpse_under(screen)
	click_on(body, ray.ground(screen))


func click_on(body: Node3D, ground: Variant) -> void:
	if body == null and ground == null:
		_log.say(Refusal.NO_TARGET)
		return
	var point: Vector3 = body.global_position if body else ground
	if _apply(armed.ability, point, body):
		armed.mode = ""
		feedback.show_ping(point)


func _aims_at_dead(ability: AbilityType) -> bool:
	return ability != null and ability.aims_at_dead()


## Every selected creature whose active ability is `ability` gets the order; the others skip it
## `point` null = no target (the creature's own spot).
func _apply(ability: AbilityType, point: Variant, body: Node3D) -> bool:
	if ability == null:
		return false
	var used := 0
	var refusal := ""
	for node in _selection.units():
		if not is_instance_valid(node) or not node is UnitBody:
			continue
		var unit := node as UnitBody
		if _ability_of(unit) != ability:
			continue
		var at: Vector3 = point if point != null else unit.global_position
		var reason := unit.abilities.port.request(at, body)
		if reason.is_empty():
			used += 1
		elif refusal.is_empty():
			refusal = reason
	_log.say(ability.display_name if used > 0 else refusal)
	return used > 0


func _ability_of(unit: UnitBody) -> AbilityType:
	var type: CreatureType = unit.type
	return type.active_ability if type else null
