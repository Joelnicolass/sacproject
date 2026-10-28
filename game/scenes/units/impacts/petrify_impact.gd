class_name PetrifyImpact
extends ShotImpact

## The Basilisk's gaze. It petrifies the
## creature it touched and nothing else: no damage, no splash. The stone lasts 2,5 s on a wizard and
## min(10, 10000 / max health) s on a creature; the body's Afflictions/Petrified decides whether it takes it.
## A wizard has its Petrified too.
## Ref: F137 (RFC-030i-b), F138 (RFC-030i-c); Basilisk dpsf, updateBasiliskProjectile (state.d:23686-23725), petrify 11641-11645.

## A creature's stone lasts min(cap_s, k / max health) seconds.
## Ref: sacengine petrify.
@export var cap_s := 10.0
@export var k := 10000.0
@export var wizard_s := 2.5
## The path of the Petrified state under each body.
@export var petrified_path := NodePath("Afflictions/Petrified")


func _affect(_shot: Node3D, target: Node3D, _point: Vector3, _ability: AbilityType) -> void:
	if target == null:
		return
	var petrified := target.get_node_or_null(petrified_path) as Petrified
	if petrified == null:
		## A building takes nothing (the original terminates on it).
		return
	petrified.petrify(lifetime_ticks(target))


## The lifetime in physics ticks: int(duration · ticks per second), truncated as the original does.
func lifetime_ticks(body: Node3D) -> int:
	var seconds := wizard_s
	if not body.is_in_group(WizardBody.GROUP):
		var health := body.get_node_or_null("Health") as Health
		var maximum := health.maximum if health else 0.0
		seconds = minf(cap_s, k / maximum) if maximum > 0.0 else cap_s
	return int(seconds * Engine.physics_ticks_per_second)
