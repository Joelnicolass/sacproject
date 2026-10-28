class_name FreezeTouch
extends WaveTouch

## The freeze of the Silverback's breath. The shot's target tries to freeze right after the blow;
## any other body that was not frozen when the wave touched it tries at the end of the update. A
## building has no Frozen. The freeze is the body's own Afflictions/Frozen with the SPEL `zerf`.

## The spell of the freeze a touched body may take (data/catalog/spells/freeze.tres: 20 s, 150 of
## spell damage when it thaws).
@export var freeze: SpellType
## The Frozen state under each body.
@export var frozen_path := NodePath("Afflictions/Frozen")

var _to_freeze: Array[Frozen] = []


## The body's Frozen when it can be frozen now (not a building, not frozen yet), read before the
## damage.
func before_hit(body: Node3D, _direct: bool, _shot: RangedShot, wave: GrowingWave) -> Variant:
	var frozen: Frozen = (
		null if wave.is_building(body) else body.get_node_or_null(frozen_path) as Frozen
	)
	return frozen if frozen != null and not frozen.is_on() else null


func after_hit(_body: Node3D, direct: bool, before: Variant, shot: RangedShot) -> void:
	var frozen := before as Frozen
	if frozen == null:
		return
	if direct:
		frozen.try_freeze_with_cooldown(_freeze_spell(), shot.from_slot)
	else:
		_to_freeze.append(frozen)


func settled(shot: RangedShot) -> void:
	for frozen in _to_freeze:
		if is_instance_valid(frozen):
			frozen.try_freeze_with_cooldown(_freeze_spell(), shot.from_slot)
	_to_freeze.clear()


func _freeze_spell() -> SpellType:
	return freeze
