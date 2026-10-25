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
## Creatures and wizards standing on the land it lifts rise with it (it can climb faster than a body can follow). Server (or solo) only.
@export var carries := false
## A body buried by the lift is carried up only if it is no deeper than this under the new surface.
@export_range(0.5, 20.0, 0.5, "suffix:m") var carry_reach_m := 6.0
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
## Only for a picture stamp (StampProfile.has_pattern): its shift at full size over `vertex_rect()`. The server works it out once,
## from the land under it, and sends it with the zone; a client plays it when it arrives (empty until then).
var pattern := PackedFloat32Array()

var _key := ""
var _deformer: TerrainDeformer
var _over := false
var _shown_share := INF


func _ready() -> void:
	process_physics_priority = -1
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	_deformer = TerrainDeformer.of(self)
	_key = String(get_path())
	set_physics_process(_deformer != null and is_ready() and not manual)


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
		return Vector2(floorf((at.x + TerrainRules.CELL * 0.5) / TerrainRules.CELL), floorf((at.y + TerrainRules.CELL * 0.5) / TerrainRules.CELL)) * TerrainRules.CELL
	return at


func is_ready() -> bool:
	return profile != null and profile.is_ready() and reach != null and reach.shape is CylinderShape3D


## Seconds since it started playing (negative before).
func local_s() -> float:
	return float(ticks - MatchClock.ticks_for(start_s)) / MatchClock.TICKS_PER_SECOND_F


## The lattice vertices it can touch.
func vertex_rect() -> Rect2i:
	return TerrainDisplacement.vertex_rect(center(), (reach.shape as CylinderShape3D).radius)


## The shift it makes at `at_s` seconds over `rect`.
func values_at(at_s: float, rect: Rect2i) -> PackedFloat32Array:
	if profile.has_pattern():
		return StampRules.scaled(profile, pattern, at_s)
	var cylinder := reach.shape as CylinderShape3D
	return StampRules.values(profile, center(), cylinder.radius, cylinder.height, at_s, rect)


## Server (or solo): works the pattern out from the land under the stamp, once. The flattening goes to the height of the center.
func _make_pattern(rect: Rect2i) -> void:
	var ground := StampRules.ground_under(_deformer.shape, rect)
	var middle := center()
	var at := Vector2i(middle / TerrainRules.CELL) - rect.position
	var target := ground[at.y * rect.size.x + at.x] if Rect2i(Vector2i.ZERO, rect.size).has_point(at) else NAN
	var cylinder := reach.shape as CylinderShape3D
	pattern = StampRules.pattern(profile, middle, cylinder.radius, cylinder.height, rect, ground, 0.0 if is_nan(target) else target)


func _physics_process(_delta: float) -> void:
	ticks += 1
	if _deformer.is_authority():
		synced_ticks = ticks
	elif absi(synced_ticks - ticks) > resync_ticks:
		ticks = synced_ticks
	if _over or ticks <= MatchClock.ticks_for(start_s):
		return
	var rect := vertex_rect()
	if profile.has_pattern() and pattern.size() != rect.size.x * rect.size.y:
		if not _deformer.is_authority():
			return
		_make_pattern(rect)
	var at := local_s()
	if at < profile.duration_s():
		var share := profile.timeline.sample(at)
		if absf(share - _shown_share) * (reach.shape as CylinderShape3D).height < min_step_m:
			return
		_shown_share = share
		_deformer.set_live(_key, rect, values_at(at, rect))
		if carries and _deformer.is_authority():
			StampCarry.lift(get_tree(), _deformer.shape, rect, carry_reach_m)
		return
	_over = true
	if keep and _deformer.is_authority():
		_deformer.commit(rect, values_at(profile.duration_s() - 1e-4, rect), _key)
	elif not keep:
		_deformer.drop_live(_key)


## Takes back at once what it shows and never plays again (whoever owns it was cut short). What it already kept stays.
func stop() -> void:
	if _deformer != null and not _over:
		_deformer.drop_live(_key)
	_over = true


func _exit_tree() -> void:
	# A stamp that keeps its mark waits for the server's commit to take its live shift away.
	if _deformer != null and is_instance_valid(_deformer) and not (keep and _over):
		_deformer.drop_live(_key)
