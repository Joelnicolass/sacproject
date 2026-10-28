class_name SpikeImpact
extends ShotImpact

## Where the Rhinok's Spikey Death stops:
## - on a body (its 5 m box met one: the target, or a body not of the shooter's side): that body takes the whole amount
##   as splash ranged damage and the rings start under its center;
## - at the end of its range (ShotLook.burst_at_range_end): if the shot's target is still a valid target it takes the
##   whole amount the same way, wherever it is; the rings start where the shot stopped.
## The rings (SpikeWave) go to the shot's parent, so they outlive the shot; they leave out the body hurt here.
## The target is hurt at the end of the range only when the range is really spent (RangedShot.range_spent): with
## GroundHugFlight the shot never bursts on the ground (holds_height), and a burst with no body before its range ends (none
## today) would hurt nobody.
## The target takes the damage through Health like any hit, so a target of the shooter's own side
## (an order on an ally) takes 0 or ally_damage_factor by the match's friendly fire (Health._side_factor).

const _HEALTH := preload("res://scenes/components/health.gd")
const _SPLASH := preload("res://scenes/spells/splash_damage.gd")

@export var wave_scene: PackedScene


func _affect(shot: Node3D, target: Node3D, point: Vector3, ability: AbilityType) -> void:
	var amount := float(shot.get("damage"))
	var from_slot := int(shot.get("from_slot"))
	var intended := _intended(shot)
	var hurt: Node3D = null
	var center := point
	var tag := ability.tag if ability else "?"
	if target != null and is_instance_valid(target) and ProjectileTargets.is_live_body(target):
		hurt = target
		center = BodyNudge.center(target)
		if DebugLog.on(&"spikes"):
			print(
				(
					"spikes %s %s hit %s at (%.3f, %.3f, %.3f) (frame %d)"
					% [tag, shot.name, target.name, point.x, point.y, point.z, MatchClock.now()]
				)
			)
	elif _range_spent(shot):
		if intended != null and ProjectileTargets.is_live_body(intended):
			hurt = intended
		if DebugLog.on(&"spikes"):
			print(
				(
					"spikes %s %s run out of range at (%.3f, %.3f, %.3f), intended %s (frame %d)"
					% [
						tag,
						shot.name,
						point.x,
						point.y,
						point.z,
						str(intended.name) + " alive" if hurt else "nobody",
						MatchClock.now()
					]
				)
			)
	elif DebugLog.on(&"spikes"):
		print(
			(
				"spikes %s %s end without a body before the range at (%.3f, %.3f, %.3f) (frame %d)"
				% [tag, shot.name, point.x, point.y, point.z, MatchClock.now()]
			)
		)
	center.y = BodyNudge.ground_y(shot, center)
	if hurt:
		_SPLASH.hurt(hurt, amount, from_slot, _HEALTH.SPLASH_RANGED, 0, shooter_of(shot))
	_start_wave(
		shot, center, amount, from_slot, intended, hurt, ability, "%s %s" % [tag, shot.name]
	)


func _range_spent(shot: Node3D) -> bool:
	return shot is RangedShot and (shot as RangedShot).range_spent()


func _intended(shot: Node3D) -> Node3D:
	var path: NodePath = shot.get("target_path") if "target_path" in shot else NodePath()
	if path.is_empty():
		return null
	return shot.get_node_or_null(path) as Node3D


func _start_wave(
	shot: Node3D,
	center: Vector3,
	amount: float,
	from_slot: int,
	intended: Node3D,
	hurt: Node3D,
	ability: AbilityType,
	label: String
) -> void:
	if wave_scene == null or shot.get_parent() == null:
		return
	var wave := wave_scene.instantiate() as SpikeWave
	if wave == null:
		push_warning("SpikeImpact: the ring scene is not a SpikeWave.")
		return
	if ability:
		wave.effect_range = ability.effect_range_m
	wave.amount = amount
	wave.from_slot = from_slot
	wave.intended = intended
	wave.touched = hurt
	var shooter := shooter_of(shot)
	wave.attacker_path = shooter.get_path() if shooter != null else NodePath()
	wave.label = label
	shot.get_parent().add_child(wave)
	wave.global_position = center
	wave.begin()
