extends DeathCloud

## Poison Cloud (cen@, Necryl). sacengine updatePoisonCloud (state.d:25235-25254): every creature (any side) whose hit box
## is within effectRange of the center gets one poison dose (state.d:25241): poison(obj, ability) = amount / duration /
## poisonNerfFactor per second for duration·60 frames, with the SPEL's `ires` / `freg` / `iacc` (state.d:11610-11614), as
## splash spell and not infectious. The dose goes through the body's Poisoning (F122, RFC-030k-a).
## Not here: `iacc` (no data carries it).

const _HEALTH := preload("res://scenes/world/components/health.gd")

## sacengine poisonNerfFactor (state.d:11610).
@export var nerf_factor := 1.3


func _affect(center: Vector3) -> void:
	if ability.duration <= 0.0:
		return
	var per_second := float(ability.damage) / ability.duration / nerf_factor
	var frames := int(ability.duration * MatchClock.TICKS_PER_SECOND)
	var ires := ability.arg_int("ires", 0)
	var freg := ability.arg_float("freg", 1.0)
	for body in bodies_within(center, ability.effect_range):
		Poisoning.dose_body(body, per_second, frames, _HEALTH.SPLASH_SPELL, from_slot, false, ires, freg)
		print("  veneno a %s %.2f/s %d cuadros ires %d freg %.2f (vida %d)" % [who(body), per_second, frames, ires, freg, roundi(float(body.get_node("Health").get("current")))])
