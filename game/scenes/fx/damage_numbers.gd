@tool
class_name DamageNumbers
extends Node3D

## Floating damage numbers. Presentation only: no RPC, no sim writes, no RNG; nothing in a headless or
## dedicated process (`run_headless` lets a check run it). FeelPrefs.damage_numbers turns them off.
## - It hears Events.body_hurt (every peer tells it) for the bodies in `body_groups`: the drop is the damage.
## - Only bodies the local player sees: visible in the tree, inside `camera`'s frustum and within `max_distance_m` of it.
## - Hits on the same body within `merge_s` add up in one number (no spam). At most `pool_size` numbers at once: a hit with
##   none free is dropped.
## - A number rises `rise_m` over `life_s` and fades out over the last `fade_s`; then it goes back to the pool (hidden).
## The look of a number is the `number_scene` Label3D (scenes/fx/damage_number.tscn); `own_color` tints the local side's bodies.
## Ref: RFC-053 053f (F375).

## Group a check counts (see `is_active`).
const GROUP := &"feel_presentation"

@export var prefs: FeelPrefs
## The camera of the local player (WorldCamera).
@export var camera: Camera3D
## Who looks at this screen (own losses read in `own_color`); empty = no body is tinted as own.
@export var seat: MpLocalSeat
@export var number_scene: PackedScene = preload("res://scenes/fx/damage_number.tscn")
@export var body_groups: PackedStringArray = PackedStringArray(["unit", "wizard", "structure", "map_building", "doctor"])
@export_range(1, 256) var pool_size := 48
@export var merge_s := 0.15
@export var life_s := 0.9
@export var fade_s := 0.35
@export var rise_m := 1.4
## Meters over the Top marker of a body (or over the top of a building's mesh) where the number starts.
@export var head_gap_m := 0.4
## Height of the number over a thing that has neither a body scene nor a mesh.
@export var default_height_m := 2.0
@export var max_distance_m := 90.0
## Damage below this is not shown (a sliver of poison or a rounding).
@export var min_amount := 1.0
## The local side's bodies (the player's own losses) read in this color; empty alpha keeps the scene's.
@export var own_color := Color(1.0, 0.42, 0.32, 1.0)
## Debug: run in a headless process too (the --feel-script check). The product leaves it off.
@export var run_headless := false

var _active := false
## Label3D of the pool not in use.
var _free: Array[Label3D] = []
## Live numbers: Label3D -> {body, amount, age, base}.
var _live: Dictionary = {}
## Body -> the Label3D it is adding to, while younger than merge_s.
var _merging: Dictionary = {}
var _base_color := Color.WHITE


## This moves by itself every frame, so physics interpolation must leave it alone.
func _init() -> void: physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ready() -> void:
	add_to_group(GROUP)
	_active = not Engine.is_editor_hint() and (run_headless or ScreenGate.is_open())
	set_process(_active)
	if not _active:
		return
	for i in pool_size:
		var label := number_scene.instantiate() as Label3D
		label.visible = false
		add_child(label)
		_free.append(label)
	if not _free.is_empty():
		_base_color = _free[0].modulate
	Events.body_hurt.connect(_on_body_hurt)


## False in headless and dedicated processes (unless `run_headless`): no pool, no listeners.
func is_active() -> bool:
	return _active


## Numbers on screen now (checks read it).
func live_count() -> int:
	return _live.size()


func _is_body(node: Node) -> bool:
	if node == null:
		return false
	for group in body_groups:
		if node.is_in_group(group):
			return true
	return false


func _on_body_hurt(body: Node3D, lost: float, _current: float, _maximum: float) -> void:
	if lost < min_amount or (prefs != null and not prefs.damage_numbers()):
		return
	if not _is_body(body) or not _seen(body):
		return
	_show(body, lost)


func _seen(body: Node3D) -> bool:
	if not body.is_visible_in_tree():
		return false
	if camera == null or not camera.is_inside_tree():
		return true
	var at := _head(body)
	return camera.global_position.distance_to(at) <= max_distance_m and camera.is_position_in_frustum(at)


func _show(body: Node3D, amount: float) -> void:
	var merging: Label3D = _merging.get(body)
	if merging != null and _live.has(merging) and float(_live[merging]["age"]) < merge_s:
		_live[merging]["amount"] = float(_live[merging]["amount"]) + amount
		merging.text = str(roundi(float(_live[merging]["amount"])))
		return
	if _free.is_empty():
		return
	var label: Label3D = _free.pop_back()
	var base := _head(body)
	_live[label] = {"body": body, "amount": amount, "age": 0.0, "base": base}
	_merging[body] = label
	label.text = str(roundi(amount))
	var own := "owner_slot" in body and seat != null and seat.is_mine(int(body.get("owner_slot")))
	label.modulate = own_color if own and own_color.a > 0.0 else _base_color
	label.global_position = base
	label.visible = true


func _process(delta: float) -> void:
	for label: Label3D in _live.keys():
		var entry: Dictionary = _live[label]
		var age := float(entry["age"]) + delta
		entry["age"] = age
		if age >= life_s:
			_release(label, entry)
			continue
		var t := age / life_s
		# Slow in, slow out: fast at first, settling at the top (ease out).
		label.global_position = (entry["base"] as Vector3) + Vector3.UP * rise_m * (1.0 - pow(1.0 - t, 2.0))
		var color := label.modulate
		color.a = clampf((life_s - age) / maxf(fade_s, 0.001), 0.0, 1.0)
		label.modulate = color
		var outline := label.outline_modulate
		outline.a = color.a
		label.outline_modulate = outline


func _release(label: Label3D, entry: Dictionary) -> void:
	_live.erase(label)
	var body: Variant = entry.get("body")
	if _merging.get(body) == label:
		_merging.erase(body)
	label.visible = false
	_free.append(label)


## Over the head: the Top marker of the body scene it wears, and `head_gap_m` more. A thing with no body scene (a building, a pillar)
## uses the top of its mesh, or `default_height_m` without one.
func _head(body: Node3D) -> Vector3:
	var top := BodyFacts.of_body(body).top if "mount" in body else Vector3(0.0, _mesh_top(body), 0.0)
	return body.global_position + top + Vector3(0.0, head_gap_m, 0.0)


func _mesh_top(body: Node3D) -> float:
	for path in [^"Tilt/Mesh", ^"Mesh"]:
		var shown := body.get_node_or_null(path) as MeshInstance3D
		if shown != null and shown.mesh != null:
			return (shown.transform * shown.get_aabb()).end.y
	return default_height_m

