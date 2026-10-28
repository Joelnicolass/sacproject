class_name RtsSelection
extends Node

## The local player's selection and its groups. Only the units of `local_slot` that are `selectable`
## can be picked; one that stops being selectable (dies) leaves the selection and every group by
## itself. The newest unit goes first: `units()` lists them newest to oldest.
##
## Click selects; Shift+click toggles; Ctrl+click (or a double click) selects the same `kind` within
## `same_type_radius`, closest first (Shift adds them). A box picks the units whose center projects
## inside it (3D: and that the camera sees past `occluder_mask`); Shift adds. `max_size` 0 = no
## limit; with a limit the newest goes first and pushes the last one out. Groups: `define_group`
## (Ctrl+N), `select_group` (N; an empty group changes nothing), `extend_group` (Shift+N). With
## `new_units_group` set, `add_new` puts a fresh unit (summoned, trained) there and in the selection.
## Works for 2D and 3D units alike. It reads no input itself (RtsSelectInput, RtsGroupKeys do).

## The selection changed (also when a unit left it by itself). Newest first.
signal changed(units: Array[RtsUnit])

## The local player's selection (one per player screen).
const GROUP := &"rts_selection"

## The player of this screen: only this slot's units can be selected.
@export var local_slot := 1
## The rectangle drawn while dragging (a Control of the HUD). Empty: none is drawn.
@export var box: Control
## 3D only: a box ignores a unit the camera cannot see because a body on these layers is in the way
## (the terrain). 0 = no check.
@export_flags_3d_physics var occluder_mask := 0
## 3D only: with `occluder_mask`, only this node (or its children) hides a unit; empty = anything on
## the mask.
@export var occluder: Node
## 0 = no limit (selection and groups).
@export var max_size := 0
@export var group_count := 10
## The group `add_new` fills (-1 = none).
@export var new_units_group := -1
## World units (meters in 3D, pixels in 2D).
@export var same_type_radius := 50.0
@export var double_click_s := 0.333
## How far apart the two clicks of a double click may be, in pixels.
@export var double_click_px := 10.0

## Read-only mirror of size() (a test flow can read a property).
var count: int:
	get:
		return size()
## Microseconds the last select_rect took (debug overlays).
var last_rect_us := 0

var _units: Array[RtsUnit] = []
## instance_id -> true for every unit in _units: has() in O(1).
var _members: Dictionary = {}
var _groups: Array = []
var _last_unit: RtsUnit
var _last_ms := -100000
var _last_at := Vector2(-1000.0, -1000.0)


func _ready() -> void:
	add_to_group(GROUP)
	_groups.clear()
	for i in group_count:
		_groups.append([])
	hide_box()


## The selected units, newest first (a copy).
func units() -> Array[RtsUnit]:
	_prune()
	return _units.duplicate()


## The selected units' bodies, newest first.
func bodies() -> Array[Node]:
	var result: Array[Node] = []
	for unit in units():
		result.append(unit.body)
	return result


func size() -> int:
	_prune()
	return _units.size()


func is_empty() -> bool:
	return size() == 0


func has(unit: Variant) -> bool:
	return (
		unit != null
		and is_instance_valid(unit)
		and _members.has((unit as Object).get_instance_id())
	)


## The units of group `index`, oldest first (a copy).
func group(index: int) -> Array[RtsUnit]:
	_prune()
	var result: Array[RtsUnit] = []
	if index < 0 or index >= _groups.size():
		return result
	for unit in _groups[index]:
		result.append(unit)
	return result


func can_select(unit: Variant) -> bool:
	if unit == null or not is_instance_valid(unit) or not unit is RtsUnit:
		return false
	var it := unit as RtsUnit
	return it.is_inside_tree() and it.selectable and it.is_owned_by(local_slot)


func clear() -> void:
	_last_unit = null
	if _units.is_empty():
		return
	_replace([])


## Leaves exactly `list` selected (in that order).
func select_only(list: Array) -> void:
	_replace(list)


## Takes `list` out of the selection; groups keep them.
func remove(list: Array) -> void:
	var gone := {}
	for unit in list:
		if is_instance_valid(unit):
			gone[(unit as Object).get_instance_id()] = true
	var next: Array = []
	for unit in _units:
		if is_instance_valid(unit) and not gone.has(unit.get_instance_id()):
			next.append(unit)
	_replace(next)


## A left click on `unit` (already known to be under the pointer at `screen`).
func click(unit: RtsUnit, screen: Vector2, shift: bool, ctrl: bool) -> void:
	if not can_select(unit):
		return
	var now := Time.get_ticks_msec()
	var again := (
		(unit == _last_unit or _last_at.distance_to(screen) < double_click_px)
		and now - _last_ms <= int(double_click_s * 1000.0)
	)
	if ctrl or again:
		if shift:
			_replace(_merge_front(_units, same_kind_near(unit)))
		else:
			var near := same_kind_near(unit)
			if not near.is_empty():
				_replace(near)
		_last_unit = null
		_last_ms = now
		_last_at = screen
		return
	if shift:
		var next: Array = _units.duplicate()
		if has(unit):
			next.erase(unit)
		else:
			next = _merge_front(next, [unit])
		_replace(next)
	else:
		_replace([unit])
	_last_unit = unit
	_last_ms = now
	_last_at = Vector2(-1000.0, -1000.0)


## A box in screen pixels: the own units whose center projects inside it (and that a 3D camera sees);
## newest first. `additive` keeps the current selection behind them.
func select_rect(from: Vector2, to: Vector2, additive: bool) -> void:
	hide_box()
	var started := Time.get_ticks_usec()
	var rect := Rect2(from, Vector2.ZERO).expand(to)
	var picked: Array[RtsUnit] = []
	var viewport := get_viewport()
	for unit in RtsUnit.all(get_tree()):
		if not can_select(unit):
			continue
		var center := unit.center_point()
		var flat := unit.is_2d()
		var screen: Variant = RtsSpace.screen_of(viewport, center, flat)
		if screen == null or not rect.has_point(screen as Vector2):
			continue
		if not flat and _hidden(center):
			continue
		picked.append(unit)
	picked.sort_custom(
		func(a: RtsUnit, b: RtsUnit) -> bool: return a.get_instance_id() > b.get_instance_id()
	)
	if max_size > 0 and picked.size() > max_size:
		picked.resize(max_size)
	var base: Array = []
	if additive:
		base = _units.duplicate()
	_replace(_merge_front(base, picked))
	last_rect_us = Time.get_ticks_usec() - started


func show_box(from: Vector2, to: Vector2) -> void:
	if box == null:
		return
	var rect := Rect2(from, Vector2.ZERO).expand(to)
	box.position = rect.position
	box.size = rect.size
	box.visible = true


func hide_box() -> void:
	if box:
		box.visible = false


## Ctrl+N: group `index` becomes the selection.
func define_group(index: int) -> void:
	if index < 0 or index >= _groups.size():
		return
	_prune()
	_groups[index] = _units.duplicate()
	_leave_new_units_group(index)


## Shift+N: the selection joins group `index`, which is then selected.
func extend_group(index: int) -> void:
	if index < 0 or index >= _groups.size():
		return
	_prune()
	for unit in _units:
		_groups[index] = _push_back(_groups[index], unit)
	_leave_new_units_group(index)
	select_group(index)


## N: group `index` becomes the selection. False (and nothing changes) when it is empty.
func select_group(index: int) -> bool:
	if index < 0 or index >= _groups.size():
		return false
	_prune()
	var members: Array = _groups[index]
	if members.is_empty():
		return false
	_replace(members)
	return true


## A unit leaves the selection and every group (it can be selected again later).
func drop(unit: RtsUnit) -> void:
	var was_selected := has(unit)
	_units.erase(unit)
	if is_instance_valid(unit):
		_members.erase(unit.get_instance_id())
	for i in _groups.size():
		(_groups[i] as Array).erase(unit)
	if is_instance_valid(unit):
		unit.selected = false
	if was_selected:
		changed.emit(_units.duplicate())


## A fresh unit of this player (summoned, trained): it joins `new_units_group` and the selection.
func add_new(unit: RtsUnit) -> void:
	if not can_select(unit):
		return
	if new_units_group >= 0 and new_units_group < _groups.size():
		_groups[new_units_group] = _push_back(_groups[new_units_group], unit)
	if not has(unit):
		_replace(_merge_front(_units, [unit]))


## The own units of `unit`'s kind within `same_type_radius` of it, closest first.
func same_kind_near(unit: RtsUnit) -> Array:
	var near: Array = []
	var at := unit.position()
	for other in RtsUnit.all(get_tree()):
		if not can_select(other) or other.kind != unit.kind:
			continue
		if other.position().distance_to(at) <= same_type_radius:
			near.append(other)
	near.sort_custom(
		func(a: RtsUnit, b: RtsUnit) -> bool:
			return a.position().distance_squared_to(at) < b.position().distance_squared_to(at)
	)
	if max_size > 0 and near.size() > max_size:
		near.resize(max_size)
	return near


func _process(_delta: float) -> void:
	if _prune():
		_mark(_units, true)
		changed.emit(_units.duplicate())


func _replace(next: Array) -> void:
	var fresh: Array[RtsUnit] = []
	var seen := {}
	for unit in next:
		if max_size > 0 and fresh.size() >= max_size:
			break
		if can_select(unit) and not seen.has(unit.get_instance_id()):
			seen[unit.get_instance_id()] = true
			fresh.append(unit)
	for unit in _units:
		if is_instance_valid(unit) and not seen.has(unit.get_instance_id()):
			unit.selected = false
	_units = fresh
	_members = seen
	_mark(_units, true)
	changed.emit(_units.duplicate())


## Drops units that can no longer be selected from the selection and the groups. True if the
## selection shrank.
func _prune() -> bool:
	var before := _units.size()
	var stale := false
	for unit in _units:
		if not can_select(unit):
			stale = true
			break
	if stale:
		var kept: Array[RtsUnit] = []
		for unit in _units:
			if can_select(unit):
				kept.append(unit)
			elif is_instance_valid(unit):
				unit.selected = false
		_units = kept
		_members.clear()
		for unit in _units:
			_members[unit.get_instance_id()] = true
	for i in _groups.size():
		var members: Array = _groups[i]
		for unit in members:
			if not can_select(unit):
				_groups[i] = members.filter(func(member: Variant) -> bool: return can_select(member))
				break
	return _units.size() != before


func _mark(list: Array, on: bool) -> void:
	for unit in list:
		if is_instance_valid(unit):
			(unit as RtsUnit).selected = on


## Defining or extending another group takes the selection out of the new-units group.
func _leave_new_units_group(index: int) -> void:
	if new_units_group < 0 or index == new_units_group or new_units_group >= _groups.size():
		return
	for unit in _units:
		(_groups[new_units_group] as Array).erase(unit)


## Each of `front` (kept in order) ahead of `base`, dropping the oldest past max_size.
func _merge_front(base: Array, front: Array) -> Array:
	var result: Array = front.duplicate()
	var seen := {}
	for unit in front:
		if is_instance_valid(unit):
			seen[(unit as Object).get_instance_id()] = true
	for unit in base:
		if is_instance_valid(unit) and not seen.has((unit as Object).get_instance_id()):
			result.append(unit)
	if max_size > 0 and result.size() > max_size:
		result.resize(max_size)
	return result


## Appended at the back; a full group drops its first unit.
func _push_back(members: Array, unit: RtsUnit) -> Array:
	var result := members.duplicate()
	if result.has(unit):
		return result
	if max_size > 0 and result.size() >= max_size:
		result.remove_at(0)
	result.append(unit)
	return result


## 3D: a body on `occluder_mask` stands between the camera and `center`.
func _hidden(center: Vector3) -> bool:
	if occluder_mask == 0:
		return false
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.get_world_3d() == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, center)
	query.collision_mask = occluder_mask
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	if occluder == null:
		return true
	var body: Object = hit.get("collider")
	return body == occluder or (body is Node and occluder.is_ancestor_of(body))
