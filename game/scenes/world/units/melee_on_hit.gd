class_name MeleeOnHit
extends Node

## F158 (RFC-030 030u-b): the passives of a creature that fire when its melee blow connects (sacengine updateCreatureAttack,
## state.d:14411-14438): the Yeti's Freeze (zerf). MeleeAttack says «connected» on the attack tick, whatever the damage roll gave;
## for every tag of `body.type.passive_abilities` that has an OnHitPassiveType here, this applies the type's two knobs
## (refuse_flying, skip_if_was_frozen) and calls Affliction.inflict(GameData.spell(tag), slot) on the target's Affliction at the
## type's path. The Affliction owns the rule (cooldown, roll, protection); a new on-hit passive is a new .tres.
## Server (or solo) only: MeleeAttack only swings there.

## Bench log (`ai_match` turns it on; off in the product): one line per passive fired.
static var log_on_hit := false

@export var melee: MeleeAttack
@export var body: UnitBody
@export var types: Array[OnHitPassiveType] = []


func _ready() -> void:
	if melee:
		melee.connected.connect(_on_connected)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if melee == null:
		warnings.append("Falta el golpe (melee).")
	if body == null:
		warnings.append("Falta el cuerpo (body).")
	return warnings


func _on_connected(target: Node3D, was_frozen: bool) -> void:
	if body == null or body.type == null or not is_instance_valid(target):
		return
	for tag in body.type.passive_abilities:
		var passive := _type_of(tag)
		if passive == null:
			continue
		if passive.skip_if_was_frozen and was_frozen:
			continue
		if passive.refuse_flying and _flies(target):
			continue
		var affliction := target.get_node_or_null(passive.affliction_path) as Affliction
		var spell := GameData.spell(tag)
		if affliction == null or spell == null:
			continue
		var took := affliction.inflict(spell, int(body.owner_slot))
		if log_on_hit:
			print("pasiva %s %s → %s %s (tick %d)" % [tag, body.name, target.name, "aplicada" if took else "sin efecto", MatchClock.now()])


func _type_of(tag: String) -> OnHitPassiveType:
	for passive in types:
		if passive != null and passive.tag == tag:
			return passive
	return null


func _flies(target: Node) -> bool:
	var flight := target.get_node_or_null("Flight") as Flight
	return flight != null and flight.is_airborne()
