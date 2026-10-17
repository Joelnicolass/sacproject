class_name ShotDropper
extends Node

## F148 (RFC-030 030h3): the droplets an Abomination's gut drops while it flies. sacengine animateAbominationProjectile
## (state.d:24441-24452): every frame of flight `numParticles = !!state.uniform(4)`, so with probability 3/4 one
## AbominationDroplet (state.d:4838-4845) is added at the shot's new position (i = 0 of 1: oldPosition·0 + position·1),
## with velocity 0. The droplet's fall and hit belong to DropletRain (one pool in the world, server only).
##
## The scene is ShotLook.dropper. RangedShot instances it on the server (or solo) only, as a child of the shot, and calls
## drop() once per physics tick, after it moved and before it checks its hit (the order of updateAbominationProjectile,
## state.d:24454-24460). Chance comes from MatchSeed: one stream per shot, ["drops", shot name].

## state.uniform(4) != 0: a droplet unless the roll is 0, i.e. (one_in − 1) / one_in of the ticks.
@export_range(1, 16) var one_in := 4
## AbominationDroplet.amount (state.d:4844): direct ranged damage, not scaled by the shooter.
@export var amount := 50.0
## updateAbominationDroplet: velocity.z −= 10/updateFPS (state.d:24491).
@export var gravity := 10.0
## abominationDropletSize (state.d:24481): side of the droplet's hit box in meters.
@export var hit_size := 0.25

## Ticks the shot flew with this dropper, and droplets it dropped.
var ticks := 0
var drops := 0
## Where the shot was on its first and on its last tick with this dropper.
var first_at := Vector3.ZERO
var last_at := Vector3.ZERO

var _rng: RandomNumberGenerator
var _rain: DropletRain
var _warned := false


func _ready() -> void:
	_rng = MatchSeed.rng(["drops", String(get_parent().name)])


## One roll per tick of flight; on a hit of the roll, a droplet at `at` for the shooter's side `from_slot`.
func drop(at: Vector3, from_slot: int) -> void:
	ticks += 1
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
			push_warning("ShotDropper: no hay DropletRain en el mundo.")
		return
	drops += 1
	_rain.add(at, amount, from_slot, gravity, hit_size)


func _exit_tree() -> void:
	if ticks > 0 and _rain != null and is_instance_valid(_rain) and _rain.log_hits:
		print("gotas %s %d de %d ticks, de (%.1f, %.1f, %.1f) a (%.1f, %.1f, %.1f)" % [get_parent().name, drops, ticks,
			first_at.x, first_at.y, first_at.z, last_at.x, last_at.y, last_at.z])
