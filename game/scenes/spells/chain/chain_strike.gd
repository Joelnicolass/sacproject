class_name ChainStrike
extends ChainEffect

## One bolt of a chain of lightning: each jump launches a LightningStrike from the last point to the next body (or to a point on the
## land), which hurts it with the spell's amount a few ticks later and draws the bolt on every peer. It does not choose whom (ChainHop)
## and it does not retarget on the way: a bolt hits who the chain chose.
## Ref: sacengine lightning with updateTargets false (state.d:18274, 10474-10491).

## The bolt (lightning_strike.tscn).
@export var strike_scene: PackedScene
## Seconds from the bolt leaving to its damage.
@export_range(0.0, 1.0, 0.001, "suffix:s") var travel_s := 12.0 / 60.0
## The BeamType every bolt draws (res://data/fx/beams/): ltn2 (the SPEL) or ltng (the exe).
@export var beam: BeamType
## The burst where a bolt hurts.
@export var hit_burst: ParticleType


func hop(chain: ChainHop, from: Vector3, body: Node3D, point: Vector3) -> void:
	var shooter := chain.wizard if is_instance_valid(chain.wizard) else null
	var look := PackedStringArray([beam.fx_name(), hit_burst.bus_name()]) if beam != null and hit_burst != null else PackedStringArray()
	LightningStrike.launch(strike_scene, chain, shooter, from, body, point, float(chain.spell.damage), chain.spell.tag, false, look,
		MatchClock.ticks_for(travel_s), chain.slot)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray(["Falta `strike_scene` (lightning_strike.tscn)."]) if strike_scene == null else PackedStringArray()
