class_name MeleeOnHit
extends Node

## The passives of a creature that fire when its melee blow connects: the Yeti's Freeze, the Dragon's Vines. MeleeAttack says
## «connected» on the attack tick, whatever the damage roll gave; for every OnHitPassiveType in `body.type.passives` this applies
## the type's two knobs (refuse_flying, skip_if_was_frozen) and calls Affliction.inflict(spell, slot) on the target's Affliction at
## the type's path. The Affliction owns the rule (cooldown, roll, protection); a new on-hit passive is a new .tres.
## Server (or solo) only: MeleeAttack only swings there.
## Ref: F158 (RFC-030 030u-b), sacengine updateCreatureAttack (state.d:14411-14438).

@export var melee: MeleeAttack
@export var body: UnitBody


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
	for entry: CreaturePassive in body.type.passives:
		var passive := entry as OnHitPassiveType
		if passive == null or passive.spell == null:
			continue
		if passive.skip_if_was_frozen and was_frozen:
			continue
		if passive.refuse_flying and _flies(target):
			continue
		var affliction := target.get_node_or_null(passive.affliction_path) as Affliction
		if affliction == null:
			continue
		var took := affliction.inflict(passive.spell, int(body.owner_slot))
		if DebugLog.on(&"on_hit"):
			print("pasiva %s %s → %s %s (tick %d)" % [passive.spell.tag, body.name, target.name, "aplicada" if took else "sin efecto", MatchClock.now()])


func _flies(target: Node) -> bool:
	var flight := target.get_node_or_null("Flight") as Flight
	return flight != null and flight.is_airborne()
