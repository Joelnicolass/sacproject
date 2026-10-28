@tool
class_name KillEffect
extends BodyEffect

## Death's blow: the body dies at once whatever it wears (a shield, a resistance), the normal way (corpse and soul stay), with `bolts` bolts of
## lightning through its center and a flash. It does not gib (GibEffect) and it does not choose who (the carrier's hunt).

## The bolt (FxBus beam type) and how many of them cross the body.
@export var beam: BeamType
@export_range(0, 8) var bolts := 3
## Each bolt is this long at least; a big body gets longer ones (1.5 times the cube root of its volume).
@export_range(0.0, 30.0, 0.5, "suffix:m") var min_length_m := 6.0
## The flash at the body: a ParticleType with a light and a sound.
@export var strike: ParticleType


func apply(carrier: SpellCarrier, body: Node3D) -> bool:
	if not is_live(body):
		return false
	var box := BodyNudge.box(body)
	var center := box.get_center()
	var half := maxf(
		min_length_m, 1.5 * pow(maxf(box.size.x * box.size.y * box.size.z, 0.0), 1.0 / 3.0)
	)
	var rng := MatchSeed.rng(["death", carrier.from_slot, MatchClock.now(), body.get_instance_id()])
	if beam != null:
		for i in bolts:
			var angle := rng.randf_range(-PI, PI)
			var along := (
				Vector3(cos(angle), rng.randf_range(-1.0, 1.0), sin(angle)).normalized() * half
			)
			FxBus.broadcast_beam(beam, center - along, center + along, null)
	if strike != null:
		FxBus.broadcast(strike, center)
	Health.of(body).kill(carrier.from_slot)
	return true
