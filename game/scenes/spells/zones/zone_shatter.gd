class_name ZoneShatter
extends ZonePulse

## What an ice zone does when it breaks: in `count` steps, from the centre outwards, every body on the ground inside the broken part takes the
## spell's damage once. It does not freeze (ZoneFreeze) nor draw the ice (the zone's look); the shards of each step come from `shards`.
## Ref: sacengine updateFrozenGround (state.d:19863-19896).

## One scene per step with the shards that fly off the broken ring: its root answers play({inner, outer}).
@export var shards: PackedScene

var _hit := {}


func _fire(step: int) -> void:
	var center := zone.points[0]
	var max_m := zone.spell.effect_range
	var inner := ZoneRules.ring_radius(step, count, max_m)
	var outer := ZoneRules.ring_radius(step + 1, count, max_m)
	if shards != null:
		FxBus.broadcast_scene(shards.resource_path, center, {"inner": inner, "outer": outer})
	for body in bodies_near(center, outer + CANDIDATE_MARGIN_M):
		var id := body.get_instance_id()
		if BodyNudge.airborne(body) or _hit.has(id) or ZoneRules.flat_gap(BodyNudge.box(body), center) > outer:
			continue
		_hit[id] = true
		SplashDamage.hurt(body, float(zone.spell.damage), zone.from_slot, Health.SPLASH_SPELL)
