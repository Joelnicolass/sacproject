class_name SpikeImpact
extends ShotImpact

## F151 (RFC-030 030n-b): where the Rhinok's Spikey Death (hrba) stops, sacengine updateRhinokProjectile, phase moving
## (state.d:24961-24983):
## - on a body (its 5 m box met one: the target, or a body not of the shooter's side): that body takes the whole amount
##   as splash ranged damage (dealRangedDamage, DamageMod.splash) and the rings start under its center
##   (centerTarget, then position.z = getHeight);
## - at the end of its range (ShotLook.burst_at_range_end): if the shot's target is still a valid target it takes the
##   whole amount the same way, wherever it is; the rings start where the shot stopped.
## The rings (SpikeWave) go to the shot's parent, so they outlive the shot; they leave out the body hurt here.
## The target is hurt at the end of the range only when the range is really spent (RangedShot.range_spent): with
## GroundHug the shot never bursts on the ground (holds_height), and a burst with no body before its range ends (none
## today) would hurt nobody.
## Declared (review m3): the target takes the damage through Health like any hit, so a target of the shooter's own side
## (an order on an ally) takes 0 or ally_damage_factor by the match's friendly fire (Health._side_factor); sacengine's
## dealRangedDamage applies its own friendly-fire rule there too (state.d:8961).

const _HEALTH := preload("res://scenes/world/components/health.gd")
const _SPLASH := preload("res://scenes/world/spells/splash_damage.gd")
const _ROCK := preload("res://scenes/world/spells/rock_projectile.gd")

@export var wave_scene: PackedScene


func _affect(shot: Node3D, target: Node3D, point: Vector3, ability: AbilityType) -> void:
	var amount := float(shot.get("damage"))
	var from_slot := int(shot.get("from_slot"))
	var intended := _intended(shot)
	var hurt: Node3D = null
	var center := point
	var tag := ability.tag if ability else "?"
	if target != null and is_instance_valid(target) and _ROCK.is_live_body(target):
		hurt = target
		center = BodyNudge.center(target)
		if SpikeWave.log_spikes:
			print("púas %s %s choca con %s en (%.3f, %.3f, %.3f) (cuadro %d)" % [tag, shot.name, target.name, point.x,
				point.y, point.z, MatchClock.now()])
	elif _range_spent(shot):
		if intended != null and _ROCK.is_live_body(intended):
			hurt = intended
		if SpikeWave.log_spikes:
			print("púas %s %s agota el alcance en (%.3f, %.3f, %.3f), pedido %s (cuadro %d)" % [tag, shot.name, point.x,
				point.y, point.z, str(intended.name) + " vivo" if hurt else "nadie", MatchClock.now()])
	elif SpikeWave.log_spikes:
		print("púas %s %s termina sin cuerpo antes del alcance en (%.3f, %.3f, %.3f) (cuadro %d)" % [tag, shot.name, point.x,
			point.y, point.z, MatchClock.now()])
	center.y = BodyNudge.ground_y(shot, center)
	if hurt:
		_SPLASH.hurt(hurt, amount, from_slot, _HEALTH.SPLASH_RANGED)
	_start_wave(shot, center, amount, from_slot, intended, hurt, ability, "%s %s" % [tag, shot.name])


func _range_spent(shot: Node3D) -> bool:
	return shot.has_method("range_spent") and bool(shot.call("range_spent"))


func _intended(shot: Node3D) -> Node3D:
	var path: NodePath = shot.get("target_path") if "target_path" in shot else NodePath()
	if path.is_empty():
		return null
	return shot.get_node_or_null(path) as Node3D


func _start_wave(shot: Node3D, center: Vector3, amount: float, from_slot: int, intended: Node3D, hurt: Node3D,
		ability: AbilityType, label: String) -> void:
	if wave_scene == null or shot.get_parent() == null:
		return
	var wave := wave_scene.instantiate() as SpikeWave
	if wave == null:
		push_warning("SpikeImpact: la escena de anillos no es un SpikeWave.")
		return
	if ability:
		wave.effect_range = ability.effect_range
	wave.amount = amount
	wave.from_slot = from_slot
	wave.intended = intended
	wave.touched = hurt
	wave.label = label
	shot.get_parent().add_child(wave)
	wave.global_position = center
	wave.begin()
