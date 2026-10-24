class_name RiftSpirit
extends SpellProjectile

## A spirit of a Demonic Rift: it leaves the rift toward one creature, hits it once, spirals up around it for four seconds, flies to a point
## in the air, comes back to the rift and sinks into it. The server (or solo) moves it and does the hit; `position`, `scale` and `status`
## are replicated, and its RiftRibbon child draws the trail on every peer. It does not choose its target (RiftSpawner) nor open the rift.
## Ref: sacengine updateDemonicRiftSpirit (state.d:19566-19606).

const _ROCK := preload("res://scenes/spells/rock_projectile.gd")

enum Status { TARGETING, RISING, MOVING_AWAY, MOVING_BACK, VANISHING }

## Every spirit in the world is in this group (the checks and the capture harness count them).
const GROUP := &"rift_spirit"

@export var hit_sound: SoundEmitter3D
@export var spawn_sound: SoundEmitter3D
@export_group("Flight")
## It flies straight out for this long before it steers.
@export_range(0.0, 3.0, 0.0001, "suffix:s") var launch_s := 0.3333
## How low over the land it skims, and how near the goal counts as arriving.
@export_range(0.0, 3.0, 0.05, "suffix:m") var skim_m := 0.3
@export_range(0.1, 5.0, 0.1, "suffix:m") var arrive_m := 1.0
@export_group("After the hit")
@export_range(0.5, 20.0, 0.5, "suffix:s") var rising_s := 4.0
@export_range(1, 20) var rising_turns := 5
@export_range(0.0, 30.0, 0.5, "suffix:m") var rising_m := 7.5
@export_range(0.0, 60.0, 0.5, "suffix:m") var away_altitude_m := 20.0
@export_range(0.1, 5.0, 0.1, "suffix:s") var vanish_s := 1.0

var status := Status.TARGETING:
	set(value):
		if value == status:
			return
		status = value
		if value != Status.MOVING_AWAY and hit_sound != null:
			hit_sound.play_once()
var velocity := Vector3.ZERO
var from_slot := 0
var speed := 18.0
var acceleration := 1.2
var damage := 500.0
var effect_range := 75.0
var goal := Vector3.ZERO
var home := Vector3.ZERO
var target_path := NodePath()
var _loud := false
var _age := 0
var _risen := 0
var _rng: RandomNumberGenerator


func setup(data: Dictionary) -> void:
	name = str(data["name"])
	position = Vector3(float(data["x"]), float(data["y"]), float(data["z"]))
	goal = data.get("goal", position)
	home = data.get("home", position)
	velocity = data.get("velocity", Vector3.ZERO)
	target_path = NodePath(str(data.get("target", "")))
	from_slot = int(data.get("slot", 0))
	speed = float(data.get("speed", speed))
	acceleration = float(data.get("acceleration", acceleration))
	damage = float(data.get("damage", damage))
	effect_range = float(data.get("range", effect_range))
	_loud = bool(data.get("loud", false))
	var net := MpReplicate.new()
	net.name = "Net"
	net.sync_properties = PackedStringArray([".:position", ".:scale", ".:status"])
	MpAuthority.ensure_sync(self, net.sync_properties)
	add_child(net)


func _ready() -> void:
	add_to_group(GROUP)
	_rng = MatchSeed.rng(["rift_spirit", String(name)])
	if _loud and spawn_sound != null:
		spawn_sound.play_once()


func _physics_process(_delta: float) -> void:
	_age += 1
	if not multiplayer.is_server():
		return
	if status == Status.VANISHING:
		position += velocity / MatchClock.TICKS_PER_SECOND_F
		scale -= Vector3.ONE / (vanish_s * MatchClock.TICKS_PER_SECOND_F)
		if scale.x <= 0.0:
			queue_free()
		return
	if _age < MatchClock.ticks_for(launch_s):
		position += velocity / MatchClock.TICKS_PER_SECOND_F
		return
	_steer()


func _steer() -> void:
	var aim := _aim()
	velocity = (velocity + (aim - global_position).normalized() * acceleration).limit_length(speed)
	global_position += velocity / MatchClock.TICKS_PER_SECOND_F
	if status != Status.RISING:
		var land := TerrainShape.of(self)
		var ground := land.height_at(global_position.x, global_position.z) if land != null else NAN
		if not is_nan(ground):
			global_position.y = maxf(global_position.y, ground + skim_m)
	if status == Status.RISING:
		_risen += 1
		if _risen >= MatchClock.ticks_for(rising_s):
			status = Status.MOVING_AWAY
			var away := ZoneRules.disk_point(_rng, effect_range)
			goal = global_position + away + Vector3(0.0, away_altitude_m, 0.0)
	elif aim.distance_to(global_position) < arrive_m:
		_arrived()


## Where it flies this tick: the creature (or the point it was given), the spiral around it, the point in the air or the rift.
func _aim() -> Vector3:
	var body := get_node_or_null(target_path) as Node3D if not target_path.is_empty() else null
	if status == Status.TARGETING and body != null:
		goal = BodyNudge.center(body)
	if status != Status.RISING:
		return goal
	var t := float(_risen) / float(maxi(MatchClock.ticks_for(rising_s), 1))
	var angle := TAU * float(rising_turns) * t
	return (BodyNudge.center(body) if body != null else goal) + Vector3(cos(angle), rising_m * t, sin(angle))


func _arrived() -> void:
	match status:
		Status.TARGETING:
			var body := get_node_or_null(target_path) as Node3D if not target_path.is_empty() else null
			if body != null and _ROCK.is_live_body(body):
				SplashDamage.hurt(body, damage, from_slot, Health.DIRECT_SPELL)
				status = Status.RISING
			else:
				status = Status.MOVING_AWAY
				goal = global_position + ZoneRules.disk_point(_rng, effect_range) + Vector3(0.0, away_altitude_m, 0.0)
		Status.MOVING_AWAY:
			status = Status.MOVING_BACK
			goal = home
		Status.MOVING_BACK:
			status = Status.VANISHING
			velocity = Vector3(0.0, -speed, 0.0)

