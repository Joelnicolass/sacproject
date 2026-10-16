extends DeathCloud

## Poison Cloud (cen@, Necryl). sacengine updatePoisonCloud (state.d:25235-25254): every creature (any side) whose hit box
## is within effectRange of the center gets one poison dose (state.d:25241): poison(obj, ability) = amount / duration /
## poisonNerfFactor per second for duration·60 frames (state.d:11610-11614). The dose is a Poisoned child.

## sacengine poisonNerfFactor (state.d:11610).
@export var nerf_factor := 1.3


func _affect(center: Vector3) -> void:
	if ability.duration <= 0.0:
		return
	var per_second := float(ability.damage) / ability.duration / nerf_factor
	var frames := int(ability.duration * Poisoned.FPS)
	for body in bodies_within(center, ability.effect_range):
		Poisoned.start(body, per_second, frames, from_slot)
		print("  veneno a %s %.2f/s %d cuadros (vida %d)" % [who(body), per_second, frames, roundi(float(body.get_node("Health").get("current")))])
