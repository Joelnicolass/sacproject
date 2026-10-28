extends DeathCloud

## Poison Cloud (cen@, Necryl). Every creature (any side) whose hit box
## is within the effect range of the center gets one poison dose: amount / duration /
## the nerf factor per second for duration·60 frames, with the SPEL's `ires` / `freg` / `iacc`, as
## splash spell and not infectious. The dose goes through the body's Poisoning.
## Not here: `iacc` (no data carries it).

const _HEALTH := preload("res://scenes/components/health.gd")

## The poison nerf factor.
@export var nerf_factor := 1.3


func _affect(center: Vector3) -> void:
	if ability.duration_s <= 0.0:
		return
	var per_second := float(ability.damage) / ability.duration_s / nerf_factor
	var frames := int(ability.duration_s * MatchClock.TICKS_PER_SECOND)
	var ires := ability.poison_resistance_debuff
	var freg := ability.poison_regen_factor
	for body in bodies_within(center, ability.effect_range_m):
		Poisoning.dose_body(body, per_second, frames, _HEALTH.SPLASH_SPELL, from_slot, false, ires, freg)
		print("  poison on %s %.2f/s %d frames ires %d freg %.2f (health %d)" % [GameBody.name_of(body), per_second, frames, ires, freg, roundi(float(body.get_node("Health").get("current")))])
