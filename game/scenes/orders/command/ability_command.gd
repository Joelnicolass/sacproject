class_name AbilityCommand
extends Node

## sacengine selectAbility (dagonBackend.d:152-178): the selection's active ability (renderedSelection ability,
## state.d:30231). One that needs a target (requiresTarget = flags != 0) arms the next left click; any other is used at
## once with no target. The click (screen or minimap) looks for a body, and for souls and corpses when the ability aims
## at them (RFC-030 030p-b). Every selected creature whose active ability is the armed one gets the order.

const _SELECTION := preload("res://scenes/orders/selection.gd")

@export var armed: ArmedCommand
@export var ray: PointerRay
@export var feedback: CommandFeedback

@onready var _log: CommandLog = %Battle
@onready var _selection: _SELECTION = %Selection


func _ready() -> void:
	%SelectionRoster.ability_pressed.connect(use)


## Ctrl+Q / Shift+B and the roster's ability icon.
func use() -> void:
	var tag := _selection.ability_tag()
	if tag.is_empty():
		return
	var ability: AbilityType = GameData.ability(tag)
	if ability and ability.flags != 0:
		armed.mode = "ability"
		armed.ability_tag = tag
		_log.arm("ability", ability.icon, "Elegí el blanco", TargetProbe.ORDER_TARGETS)
		return
	_apply(tag, null, null)


func click_at(screen: Vector2) -> void:
	var body := ray.body_under(screen, false)
	## RFC-030 030p-b: an ability that aims at souls or corpses (Breath of life) looks for them after the living body.
	if body == null and _aims_at_dead(armed.ability_tag):
		body = ray.soul_under(screen)
		if body == null:
			body = ray.corpse_under(screen)
	click_on(body, ray.ground(screen))


func click_on(body: Node3D, ground: Variant) -> void:
	if body == null and ground == null:
		_log.say(Refusal.NO_TARGET)
		return
	var point: Vector3 = body.global_position if body else ground
	if _apply(armed.ability_tag, point, body):
		armed.mode = ""
		feedback.show_ping(point)


## spells.d:168-183: targetSouls (1 << 1) and targetCorpses (1 << 3).
func _aims_at_dead(tag: String) -> bool:
	var ability: AbilityType = GameData.ability(tag)
	return ability != null and (ability.flags & ((1 << 1) | (1 << 3))) != 0


## Every selected creature whose active ability is `tag` gets the order; the others skip it
## (applyOrder, state.d:29256). `point` null = no target (the creature's own spot).
func _apply(tag: String, point: Variant, body: Node3D) -> bool:
	var used := 0
	var refusal := ""
	for node in _selection.units():
		if not is_instance_valid(node) or not node is UnitBody:
			continue
		var unit := node as UnitBody
		if _ability_of(unit) != tag:
			continue
		var at: Vector3 = point if point != null else unit.global_position
		var reason := unit.request_ability(at, body)
		if reason.is_empty():
			used += 1
		elif refusal.is_empty():
			refusal = reason
	var ability: AbilityType = GameData.ability(tag)
	_log.say((ability.display_name if ability else tag) if used > 0 else refusal)
	return used > 0


func _ability_of(unit: UnitBody) -> String:
	var type: CreatureType = unit.type
	return type.active_ability_tag if type else ""
