@tool
class_name TerrainStamp
extends Node3D

## A shape pressed on the ground under this node: it raises (or digs) the land around it following its StampProfile
## while it plays, and goes back to nothing when it is over, or leaves what it reached for good (`keep`). Its size is the
## `Reach` cylinder you see in the editor (radius = how far it reaches, height = the peak); move it with the gizmo. It
## plays on every peer from its own count of ticks and asks the map's Terrain to show it; the server alone decides what
## stays. A `manual` stamp does not play: `leave_now()` leaves its mark at once. It does not know the spell it belongs to.

## The shape. Shared by the stamps that point to it.
@export var profile: StampProfile
## The cylinder that says how far it reaches (radius) and how high it goes (height).
@export var reach: CollisionShape3D
## It starts this long after it was born.
@export_range(0.0, 60.0, 0.01, "suffix:s") var start_s := 0.0
## When it is over, what it reached stays on the ground for good (a crater); off, the ground goes back.
@export var keep := false
## It shows a new shift only when it differs from the last one shown by this many metres of its peak (a slow decline is not redrawn each tick).
@export_range(0.0, 2.0, 0.01, "suffix:m") var min_step_m := 0.0
## It does not play by itself: something else leaves its mark at once (DropDent, a meteorite's dent).
@export var manual := false
## Ticks a peer may be off the server's count before it takes the server's.
@export_range(1, 60) var resync_ticks := 8

## Ticks since it was born, on this peer.
var ticks := 0
## The server's count of ticks, sent to the clients so one that joins late (or lags) plays the same moment.
var synced_ticks := 0
## Only for a picture stamp (StampProfile.has_pattern): its shift at full size around `center()`. The server works it out once,
## from the land under it, and sends it with the zone; a client plays it when it arrives (empty until then).
var pattern := PackedFloat32Array()

var _key := &""
var _terrain: Terrain
var _over := false
var _shown_share := INF


func _ready() -> void:
	process_physics_priority = -1
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	_terrain = Terrain.of(self)
	_key = StringName(String(get_path()))
	set_physics_process(_terrain != null and is_ready() and not manual)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if profile == null or not profile.is_ready():
		warnings.append("Falta `profile` (StampProfile con radial y timeline; el anillo pide ring_travel y ring_width).")
	if reach == null or not reach.shape is CylinderShape3D:
		warnings.append("Falta `reach`: un CollisionShape3D con un cilindro (radio = alcance, alto = pico).")
	return warnings


## Where it presses, x and z in metres. A picture stamp is fixed to the 10 m lattice (the nearest vertex).
func center() -> Vector2:
	var at := Vector2(global_position.x, global_position.z)
	if profile != null and profile.heightmap != null:
		return TerrainGrid.point_of(TerrainGrid.vertex_near(at))
	return at


func is_ready() -> bool:
	return profile != null and profile.is_ready() and reach != null and reach.shape is CylinderShape3D


## Seconds since it started playing (negative before).
func local_s() -> float:
	return float(ticks - MatchClock.ticks_for(start_s)) / MatchClock.TICKS_PER_SECOND_F


## Server (or solo): leaves its mark for good right now, as it is at its end (a `manual` stamp: a meteorite's dent).
func leave_now() -> void:
	if _terrain != null and is_ready():
		_terrain.keep_stamp(_key, profile, center(), _reach_m(), _peak_m(), pattern)


func _physics_process(_delta: float) -> void:
	ticks += 1
	if _terrain.is_authority():
		synced_ticks = ticks
	elif absi(synced_ticks - ticks) > resync_ticks:
		ticks = synced_ticks
	if _over or ticks <= MatchClock.ticks_for(start_s):
		return
	if profile.has_pattern() and pattern.size() != _vertex_count():
		if not _terrain.is_authority():
			return
		pattern = _terrain.stamp_pattern(profile, center(), _reach_m(), _peak_m())
	var at := local_s()
	if at < profile.duration_s():
		var share := profile.timeline.sample(at)
		if absf(share - _shown_share) * _peak_m() < min_step_m:
			return
		_shown_share = share
		_terrain.stamp(_key, profile, center(), _reach_m(), _peak_m(), at, pattern)
		return
	_over = true
	if keep and _terrain.is_authority():
		_terrain.keep_stamp(_key, profile, center(), _reach_m(), _peak_m(), pattern)
	elif not keep:
		_terrain.unstamp(_key)


## Takes back at once what it shows and never plays again (whoever owns it was cut short). What it already kept stays.
func stop() -> void:
	if _terrain != null and not _over:
		_terrain.unstamp(_key)
	_over = true


func _exit_tree() -> void:
	# A stamp that keeps its mark waits for the server's keep to take its live shift away.
	if _terrain != null and is_instance_valid(_terrain) and not (keep and _over):
		_terrain.unstamp(_key)


func _reach_m() -> float:
	return (reach.shape as CylinderShape3D).radius


func _peak_m() -> float:
	return (reach.shape as CylinderShape3D).height


## How many lattice vertices it touches (the size of its `pattern`).
func _vertex_count() -> int:
	return TerrainGrid.vertex_rect(center(), _reach_m()).get_area()
