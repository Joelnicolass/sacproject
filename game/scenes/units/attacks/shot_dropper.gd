class_name ShotDropper
extends ShotInFlight

## The droplets an Abomination's gut drops while it flies: every
## frame of flight, with probability 3/4, one droplet is added at the shot's new position,
## with velocity 0. The droplet's fall and hit belong to DropletRain (one pool in the world, server only).
##
## The scene is ShotLook.in_flight (a ShotInFlight). RangedShot instances it on the server (or solo) only, as a
## child of the shot, and calls fly() once per physics tick, after it moved and before it checks its hit. Chance comes from MatchSeed: one stream per shot, ["drops", shot name].

## A droplet unless the roll is 0, i.e. (one_in − 1) / one_in of the ticks.
@export_range(1, 16) var one_in := 4
## Direct ranged damage of a droplet, not scaled by the shooter.
@export var amount := 50.0
## The droplet's fall: velocity.z −= 10/60.
@export var gravity := 10.0
## Side of the droplet's hit box in meters.
@export var hit_size := 0.25

## Droplets it dropped (the ticks are ShotInFlight's).
var drops := 0
## Where the shot was on its first and on its last tick with this dropper.
var first_at := Vector3.ZERO
var last_at := Vector3.ZERO

var _rng: RandomNumberGenerator
var _rain: DropletRain
var _warned := false


func _ready() -> void:
	_rng = MatchSeed.rng(["drops", String(get_parent().name)])


func _fly(shot: RangedShot, at: Vector3) -> void:
	drop(at, shot.from_slot)


## One roll per tick of flight (fly() already counted it); on a hit of the roll, a droplet at `at` for the shooter's
## side `from_slot`.
func drop(at: Vector3, from_slot: int) -> void:
	if ticks == 1:
		first_at = at
	last_at = at
	if _rng.randi() % one_in == 0:
		return
	if _rain == null or not is_instance_valid(_rain):
		_rain = get_tree().get_first_node_in_group(DropletRain.GROUP) as DropletRain
	if _rain == null:
		if not _warned:
			_warned = true
			push_warning("ShotDropper: no DropletRain in the world.")
		return
	drops += 1
	_rain.add(at, amount, from_slot, gravity, hit_size)


func _exit_tree() -> void:
	if ticks > 0 and _rain != null and is_instance_valid(_rain) and _rain.log_hits:
		print(
			(
				"drops %s %d of %d ticks, from (%.1f, %.1f, %.1f) to (%.1f, %.1f, %.1f)"
				% [
					get_parent().name,
					drops,
					ticks,
					first_at.x,
					first_at.y,
					first_at.z,
					last_at.x,
					last_at.y,
					last_at.z
				]
			)
		)
