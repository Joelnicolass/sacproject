class_name ChainHeal
extends ChainEffect

## One arc of Rainbow: each jump draws an arch from the last point to the next ally (it follows the
## ally while it travels) and when it lands it cures all the ally's health through HealEffect (the
## same cure in time as Heal) and throws a burst of colored sparks. It does not choose whom
## (ChainHop) nor heal by itself: HealEffect owns the cure.

## The arch (a BeamType with path ARC under scenes/fx/effects/beams/).
@export var beam: BeamType
## The sparks where the arch lands (a ParticleType under scenes/fx/effects/).
@export var burst: ParticleType


func hop(_chain: ChainHop, from: Vector3, body: Node3D, point: Vector3) -> void:
	if beam != null:
		FxBus.broadcast_beam(beam, from, BodyNudge.center(body) if body != null else point, body)


func land(_chain: ChainHop, body: Node3D, _point: Vector3) -> void:
	if body == null:
		return
	if burst != null:
		FxBus.broadcast(burst, BodyNudge.center(body))
	HealEffect.heal_full(body)
