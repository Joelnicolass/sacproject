@tool
class_name TerrainStamp
extends Node3D

## A shape pressed on the ground under this node: it raises (or digs) the land around it following its StampProfile
## while it plays, and goes back to nothing when it is over, or leaves what it reached for good (`keep`). Its size is the
## `Reach` cylinder you see in the editor (radius = how far it reaches, height = the peak); move it with the gizmo. It
## plays on every peer from its own count of ticks and asks the map's TerrainDeformer to show it; the server alone
## decides what stays. It does not know the spell it belongs to.

## The shape. Shared by the stamps that point to it.
@export var profile: StampProfile
## The cylinder that says how far it reaches (radius) and how high it goes (height).
@export var reach: CollisionShape3D
## It starts this long after it was born.
@export_range(0.0, 60.0, 0.01, "suffix:s") var start_s := 0.0
## When it is over, what it reached stays on the ground for good (a crater); off, the ground goes back.
@export var keep := false
## Ticks a peer may be off the server's count before it takes the server's.
@export_range(1, 60) var resync_ticks := 8

## Ticks since it was born, on this peer.
var ticks := 0
## The server's count of ticks, sent to the clients so one that joins late (or lags) plays the same moment.
var synced_ticks := 0

var _key := ""
var _deformer: TerrainDeformer
var _over := false


func _ready() -> void:
	process_physics_priority = -1
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	_deformer = TerrainDeformer.of(self)
	_key = String(get_path())
	set_physics_process(_deformer != null and is_ready())


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if profile == null or not profile.is_ready():
		warnings.append("Falta `profile` (StampProfile con radial y timeline; el anillo pide ring_travel y ring_width).")
	if reach == null or not reach.shape is CylinderShape3D:
		warnings.append("Falta `reach`: un CollisionShape3D con un cilindro (radio = alcance, alto = pico).")
	return warnings


func is_ready() -> bool:
	return profile != null and profile.is_ready() and reach != null and reach.shape is CylinderShape3D


## Seconds since it started playing (negative before).
func local_s() -> float:
	return float(ticks - MatchClock.ticks_for(start_s)) / MatchClock.TICKS_PER_SECOND_F


## The lattice vertices it can touch.
func vertex_rect() -> Rect2i:
	return TerrainDisplacement.vertex_rect(Vector2(global_position.x, global_position.z), (reach.shape as CylinderShape3D).radius)


## The shift it makes at `at_s` seconds over `rect`.
func values_at(at_s: float, rect: Rect2i) -> PackedFloat32Array:
	var cylinder := reach.shape as CylinderShape3D
	return StampRules.values(profile, Vector2(global_position.x, global_position.z), cylinder.radius, cylinder.height, at_s, rect)


func _physics_process(_delta: float) -> void:
	ticks += 1
	if _deformer.is_authority():
		synced_ticks = ticks
	elif absi(synced_ticks - ticks) > resync_ticks:
		ticks = synced_ticks
	if _over or ticks <= MatchClock.ticks_for(start_s):
		return
	var rect := vertex_rect()
	var at := local_s()
	if at < profile.duration_s():
		_deformer.set_live(_key, rect, values_at(at, rect))
		return
	_over = true
	if keep and _deformer.is_authority():
		_deformer.commit(rect, values_at(profile.duration_s() - 1e-4, rect), _key)
	elif not keep:
		_deformer.drop_live(_key)


func _exit_tree() -> void:
	# A stamp that keeps its mark waits for the server's commit to take its live shift away.
	if _deformer != null and is_instance_valid(_deformer) and not (keep and _over):
		_deformer.drop_live(_key)
