class_name QuakeWave
extends Node3D

## F132 (RFC-030 030u-a): the Jabberocky's Quake (mtse, SPEL kauq): sacengine Quake (state.d:5187-5225) updated by
## updateQuake (25737-25759). QuakeAbility puts it in the shot container at the user's feet on the tick the shot fires
## (quake, 13204-13207), server (or solo) only: a client never gets this node. Priority −1: effects update before
## creatures (29331 against 29345).
##
## Its frame is MatchClock.now() − the tick it was born; the birth tick is discarded (the first update is the next one,
## frame 1). On every frame:
## - frame 1: quakeExplosion (64 dirt particles and the shake: the look, FxBus);
## - the wave is at waveLoc = wave_range · (frame / 60) / wave_s (1,667 m per frame, float32 as sacengine);
## - while stun_min < waveLoc < stun_max (frames 1 to 5), every moving body of `groups`, any side (wizards too, the user
##   if it stood there), whose hit box is within waveLoc + 0,1 and whose feet are, seen from above, farther than stun_min
##   and within `band`·wave_range / (wave_s · 60) (2,5 m) of the wave takes Stunned.stun_with_cooldown(cooldown_ticks).
##   No damage;
## - the effect ends when the frame goes past total_frames (30): the node is freed on frame 31.
## The stun is each body's Afflictions/Stunned (canStun, its own cooldown): a stunned one is skipped by it.
##
## Deviations (declared): the land does not bend (sacengine Quake.displacement is a render effect); the look is
## quake_ring.tscn (a ring of earth, MIX) plus dirt; no sound.

## Bench log (`ai_match` turns it on; off in the product; agent/tools/f132_expect.py reads it).
static var log_quake := false

## sacengine Quake.waveRange (m) and waveDur (s).
@export var wave_range := 50.0
@export var wave_s := 0.5
## sacengine stunMinRange / stunMaxRange (m): the wave stuns only between them.
@export var stun_min := 0.5
@export var stun_max := 10.0
## The band the wave stuns, in frames of travel: 1,5 (sacengine 1.5·waveRange/(waveDur·updateFPS) = 2,5 m).
@export var band := 1.5
## sacengine stunCooldownFrames = 8·updateFPS.
@export var cooldown_ticks := 480
## sacengine totalFrames = int(waveDur·updateFPS + 0.5).
@export var total_frames := 30
## sacengine movingObjects: creatures and wizards (buildings are not stunned).
@export var groups: Array[StringName] = [&"wizard", &"unit"]
## The path of the Stunned state under each body.
@export var stunned_path := NodePath("Afflictions/Stunned")
## The ring of earth (QuakeRing, FxBus.broadcast_scene) and the dust of the explosion (FxBus type; empty: none).
@export_file("*.tscn") var ring_scene := "res://scenes/fx/quake_ring.tscn"
@export var dust_fx := "dirt"

## For the log: the user's name and the SPEL tag (kauq).
var label := ""

var _born := -1
var _last_frame := 0


## The wave of `scene` in the shot container at `feet`, or null (and a warning) when there is none. `from` is any node of
## the tree.
static func launch(scene: PackedScene, from: Node, feet: Vector3, tag: String) -> QuakeWave:
	if scene == null or from == null or not from.is_inside_tree():
		return null
	var spawner := from.get_tree().get_first_node_in_group(&"shot_spawner")
	var container := spawner.get_node_or_null(spawner.get("spawn_path")) if spawner != null else null
	if container == null:
		push_warning("QuakeWave: no hay contenedor de disparos (grupo shot_spawner).")
		return null
	var wave := scene.instantiate() as QuakeWave
	if wave == null:
		push_warning("QuakeWave: la escena no es un QuakeWave.")
		return null
	wave.label = tag
	container.add_child(wave, true)
	wave.global_position = feet
	wave.begin()
	return wave


## Once it is in the tree where it stands: this tick is frame 0 (the shot's).
func begin() -> void:
	_born = MatchClock.now()
	if log_quake:
		var at := global_position
		print("onda %s en (%.3f, %.3f, %.3f) alcance %.1f m %.2f s aturde de %.1f a %.1f m banda %.3f m por %d (cuadro %d)" % [
			label, at.x, at.y, at.z, wave_range, wave_s, stun_min, stun_max, band_meters(), cooldown_ticks, _born])


func _physics_process(_delta: float) -> void:
	if _born < 0:
		return
	var frame := MatchClock.now() - _born
	if frame <= _last_frame:
		return
	for f in range(_last_frame + 1, frame + 1):
		if f > total_frames:
			_end(f)
			return
		_step(f)
	_last_frame = frame


## waveLoc of frame `f`, float32 step by step: waveRange·(float(frame)/updateFPS)/waveDur.
func wave_at(f: int) -> float:
	var ticks := float(MatchClock.TICKS_PER_SECOND)
	return SacFloat.f32(SacFloat.f32(wave_range * SacFloat.f32(float(f) / ticks)) / wave_s)


## The half-width of the stunned band (m): 1.5·waveRange/(waveDur·updateFPS).
func band_meters() -> float:
	var ticks := float(MatchClock.TICKS_PER_SECOND)
	return SacFloat.f32(SacFloat.f32(band * wave_range) / SacFloat.f32(wave_s * ticks))


func _step(f: int) -> void:
	if f == 1:
		_explode()
	var loc := wave_at(f)
	if not (stun_min < loc and loc < stun_max):
		return
	var center := global_position
	var reach := SacFloat.f32(loc + 0.1)
	var half_band := band_meters()
	if log_quake:
		print("onda %s paso %d radio %.3f m (cuadro %d)" % [label, f, loc, MatchClock.now()])
	for body in SplashDamage.bodies_within(get_tree(), center, reach, null, groups):
		var feet := body.global_position
		var flat := Vector2(feet.x - center.x, feet.z - center.z).length()
		var result := "fuera de la banda"
		if stun_min < flat and absf(flat - loc) < half_band:
			result = _stun(body)
		if log_quake:
			print("  onda %s %s a %.3f m en planta, caja %.3f m: %s (cuadro %d)" % [label, body.name, flat,
				SplashDamage.box_distance(body, center), result, MatchClock.now()])


## sacengine stunWithCooldown on a body of the band; what happened, for the log.
func _stun(body: Node3D) -> String:
	var stunned := body.get_node_or_null(stunned_path) as Stunned
	if stunned == null:
		return "sin Stunned"
	if stunned.stun_with_cooldown(cooldown_ticks):
		return "aturdido"
	return "sin efecto, enfriamiento %d" % stunned.cooldown_ticks() if stunned.cooldown_ticks() > 0 else "sin efecto"


## quakeExplosion (frame 1): the look. Presentation, every peer.
func _explode() -> void:
	if not dust_fx.is_empty():
		FxBus.broadcast(dust_fx, global_position)
	if not ring_scene.is_empty():
		FxBus.broadcast_scene(ring_scene, global_position, {"range": wave_range, "seconds": wave_s})


func _end(frame: int) -> void:
	if log_quake:
		print("onda %s fin paso %d (cuadro %d)" % [label, frame, MatchClock.now()])
	set_physics_process(false)
	queue_free()
