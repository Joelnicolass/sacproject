class_name QuakeWave
extends Node3D

## The Jabberocky's Quake (and the burst of Bovine Intervention's cow): a wave of earth that goes out 50 m from the user's feet
## in half a second, stuns the bodies it crosses near the center and bends the land while it lasts. Quake puts it in the
## shot container at the user's feet on the tick the shot fires, server (or solo) only: a client never gets this node. It does
## not hurt, and it does not draw the ring (QuakeRing) nor shape the ground (its child Ground, quake_ground.tscn).
##
## Its frame is MatchClock.now() − the tick it was born; the birth tick is discarded (the first update is the next one,
## frame 1). On every frame:
## - frame 1: the explosion (64 dirt particles and the shake: the look, FxBus);
## - the wave is at wave_range · (frame / 60) / wave_s (1,667 m per frame, float32);
## - while stun_min < wave < stun_max (frames 1 to 5), every moving body of `groups`, any side (wizards too, the user
##   if it stood there), whose hit box is within wave + 0,1 and whose feet are, seen from above, farther than stun_min
##   and within `band`·wave_range / (wave_s · 60) (2,5 m) of the wave takes Stunned.stun_with_cooldown(cooldown_s).
##   No damage;
## - the effect ends when the frame goes past life_s (30 ticks): the node is freed on frame 31 (and Ground with it).
## The stun is each body's Afflictions/Stunned (its own cooldown): a stunned one is skipped by it.
## The land: Ground's two TerrainStamps (the sinking and the wave) play here on the server, so the bodies follow the ground;
## a client sees the copy in quake_ring.tscn (on_clients_only). Priority −1: effects update before creatures.
##
## Limits: the look is quake_ring.tscn (a ring of earth, MIX) plus dirt; no sound.

## How far the wave goes (m) and how long it takes (s).
@export var wave_range := 50.0
@export var wave_s := 0.5
## The wave stuns only between these two distances (m).
@export var stun_min := 0.5
@export var stun_max := 10.0
## The band the wave stuns, in frames of travel: 1,5 (1.5·wave_range/(wave_s·ticks per second) = 2,5 m).
@export var band := 1.5
## How long a stunned body cannot be stunned again.
@export_range(0.0, 60.0, 0.0001, "suffix:s") var cooldown_s := 8.0
## How long the wave lasts.
@export_range(0.0, 10.0, 0.0001, "suffix:s") var life_s := 0.5
## Moving bodies: creatures and wizards (buildings are not stunned).
@export var groups: Array[StringName] = [&"wizard", &"unit"]
## The path of the Stunned state under each body.
@export var stunned_path := NodePath("Afflictions/Stunned")
## The ring of earth (quake_ring.tscn, an FxScene played on every peer) and the dust of the explosion. Empty: none.
@export var ring_scene: PackedScene
@export var dust_fx: ParticleType

## For the log: the user's name and the SPEL tag (kauq).
var label := ""

var _born := -1
var _last_frame := 0


## The wave of `scene` in the shot container at `feet`, or null (and a warning) when there is none. `from` is any node of
## the tree.
static func launch(scene: PackedScene, from: Node, feet: Vector3, tag: String) -> QuakeWave:
	if scene == null or from == null or not from.is_inside_tree():
		return null
	var spawner := from.get_tree().get_first_node_in_group(ShotSpawner.GROUP)
	var container := (
		spawner.get_node_or_null(spawner.get("spawn_path")) if spawner != null else null
	)
	if container == null:
		push_warning("QuakeWave: no shot container (group shot_spawner).")
		return null
	var wave := scene.instantiate() as QuakeWave
	if wave == null:
		push_warning("QuakeWave: the scene is not a QuakeWave.")
		return null
	wave.label = tag
	container.add_child(wave, true)
	wave.global_position = feet
	wave.begin()
	return wave


## Once it is in the tree where it stands: this tick is frame 0 (the shot's).
func begin() -> void:
	_born = MatchClock.now()
	if DebugLog.on(&"quake"):
		var at := global_position
		print(
			(
				"wave %s at (%.3f, %.3f, %.3f) range %.1f m %.2f s stuns from %.1f to %.1f m band %.3f m for %d (frame %d)"
				% [
					label,
					at.x,
					at.y,
					at.z,
					wave_range,
					wave_s,
					stun_min,
					stun_max,
					band_meters(),
					MatchClock.ticks_for(cooldown_s),
					_born
				]
			)
		)


func _physics_process(_delta: float) -> void:
	if _born < 0:
		return
	var frame := MatchClock.now() - _born
	if frame <= _last_frame:
		return
	var last := MatchClock.ticks_for(life_s)
	for f in range(_last_frame + 1, frame + 1):
		if f > last:
			_end(f)
			return
		_step(f)
	_last_frame = frame


## Where the wave is on frame `f`: wave_range·(frame/60)/wave_s.
func wave_at(f: int) -> float:
	var ticks := float(MatchClock.TICKS_PER_SECOND)
	return wave_range * (float(f) / ticks) / wave_s


## The half-width of the stunned band (m): 1.5·wave_range/.
func band_meters() -> float:
	var ticks := float(MatchClock.TICKS_PER_SECOND)
	return band * wave_range / (wave_s * ticks)


func _step(f: int) -> void:
	if f == 1:
		_explode()
	var loc := wave_at(f)
	if not (stun_min < loc and loc < stun_max):
		return
	var center := global_position
	var reach := loc + 0.1
	var half_band := band_meters()
	if DebugLog.on(&"quake"):
		print("wave %s step %d radius %.3f m (frame %d)" % [label, f, loc, MatchClock.now()])
	for body in SplashDamage.bodies_within(get_tree(), center, reach, null, groups):
		var feet := body.global_position
		var flat := Vector2(feet.x - center.x, feet.z - center.z).length()
		var result := "outside the band"
		if stun_min < flat and absf(flat - loc) < half_band:
			result = _stun(body)
		if DebugLog.on(&"quake"):
			print(
				(
					"  wave %s %s at %.3f m flat, box %.3f m: %s (frame %d)"
					% [
						label,
						body.name,
						flat,
						SplashDamage.box_distance(body, center),
						result,
						MatchClock.now()
					]
				)
			)


## Stuns a body of the band with the cooldown rule; what happened, for the log.
func _stun(body: Node3D) -> String:
	var stunned := body.get_node_or_null(stunned_path) as Stunned
	if stunned == null:
		return "no Stunned"
	if stunned.stun_with_cooldown(MatchClock.ticks_for(cooldown_s)):
		return "aturdido"
	return (
		"no effect, cooldown %d" % stunned.cooldown_ticks()
		if stunned.cooldown_ticks() > 0
		else "no effect"
	)


## The explosion (frame 1): the look. Presentation, every peer.
func _explode() -> void:
	if dust_fx != null:
		FxBus.broadcast(dust_fx, global_position)
	if ring_scene != null:
		FxBus.broadcast_scene(ring_scene, global_position, {"range": wave_range, "seconds": wave_s})


func _end(frame: int) -> void:
	if DebugLog.on(&"quake"):
		print("wave %s end step %d (frame %d)" % [label, frame, MatchClock.now()])
	set_physics_process(false)
	queue_free()
