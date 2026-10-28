class_name MeleeOnHit
extends UnitPassive

## An affliction a creature's melee blow lays when it connects, whatever the damage roll gave: the
## Yeti's Freeze, the Dragon's Grasping Vines. On every connection it calls
## Affliction.inflict(spell, slot) on the target's Affliction at `affliction_path`; the Affliction
## owns the rule (cooldown, roll, protection). A node of the creature's `<name>_passives.tscn`, one
## per effect. Not: the blow itself (MeleeWeapon). Server (or solo) only: the weapon only swings
## there.

## The spell the affliction takes (data/catalog/spells/).
@export var spell: SpellType
## The Affliction under the target body ("Afflictions/Frozen").
@export var affliction_path := NodePath("")
## A target in the air is spared (the Vines).
@export var refuse_flying := false
## A blow on a body that was frozen before it does not lay it again (the Freeze: that blow breaks
## the ice).
@export var skip_if_was_frozen := false


func attach(mount: PassiveMount) -> void:
	super(mount)
	mount.melee.connected.connect(_on_connected)


func _on_connected(target: Node3D, was_frozen: bool) -> void:
	if spell == null or not is_instance_valid(target):
		return
	if skip_if_was_frozen and was_frozen:
		return
	if refuse_flying and _flies(target):
		return
	var affliction := target.get_node_or_null(affliction_path) as Affliction
	if affliction == null:
		return
	var took := affliction.inflict(spell, int(body.owner_slot))
	if DebugLog.on(&"on_hit"):
		var said := "aplicada" if took else "sin efecto"
		print("pasiva %s %s → %s %s (tick %d)" % [spell.tag, body.name, target.name, said, MatchClock.now()])


func _flies(target: Node) -> bool:
	var flight := target.get_node_or_null("Flight") as Flight
	return flight != null and flight.is_airborne()
