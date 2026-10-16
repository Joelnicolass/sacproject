extends Node

## The local player's creature selection and groups (sacengine SideData, state.d:30258).
## Client-side: only own creatures (canSelect, state.d:1134: same side, not a wizard, not dead).
## No limit by default (RFC-025, max_size 0). With max_size = 12 (numCreaturesInGroup) the classic
## mode returns: the newest goes first and pushes the last one out.
##
## Click selects; Shift+click toggles; Ctrl+click selects that type within 50 m (selectAll,
## state.d:29867), Ctrl+Shift adds them; a double click acts like Ctrl+click
## (dagonBackend.d:1173-1198). A left drag of 3 px or more draws a rectangle (Shift adds).
## Groups 1–0: Ctrl+N defines, N selects (an empty group changes nothing), Shift+N adds.
## Summoned creatures join the selection and group 0 (newCreatureAddToSelection, state.d:29959).
## Own creatures show their health bar only while selected (renderer.d:3890-3895).

signal changed(units: Array)

## Rectangle drawn while dragging (white frame, renderer.d:4030).
@export var box: Control
## Only this ground blocks the camera's line of sight for the rectangle (terrainLineOfSight).
@export var ground: Node3D
## 0 = no limit (selection, groups and the summon group); 12 = the original numCreaturesInGroup.
@export var max_size := 0
@export var group_count := 10
## groups[$-1] gathers new summons.
@export var summon_group := 9
@export var same_type_radius := 50.0
## options.doubleClickSpeed: 20 frames at 60 fps.
@export var double_click_s := 0.333
## renderer targetCacheDelta.
@export var double_click_px := 10.0

## Read-only mirror of size() so flows can assert it (AgentKit reads properties, not methods).
var count: int:
	get:
		return size()
var _units: Array[Node3D] = []
## instance_id -> true for every unit in _units: has() in O(1).
var _members: Dictionary = {}
## Microseconds the last select_rect took (debug overlays).
var last_rect_us := 0
var _groups: Array = []
var _last_unit: Node3D
var _last_ms := -100000
var _last_at := Vector2(-1000.0, -1000.0)


func _ready() -> void:
	add_to_group("selection")
	for i in group_count:
		_groups.append([])
	hide_box()


func units() -> Array[Node3D]:
	_prune()
	return _units.duplicate()


func size() -> int:
	_prune()
	return _units.size()


func has(unit: Variant) -> bool:
	return unit != null and is_instance_valid(unit) and _members.has((unit as Object).get_instance_id())


## Tag of the active ability the selection offers: the newest selected creature that has one wins
## (sacengine renderedSelection ability; CRE8 priority is not exported). "" = none. MatchCommand
## (Ctrl+Q) and the roster's ability icon both read it, so they never disagree.
func ability_tag() -> String:
	for unit in units():
		if not unit.has_method("request_ability"):
			continue
		var type: CreatureType = unit.get("type")
		if type and not type.active_ability_tag.is_empty():
			return type.active_ability_tag
	return ""


func clear() -> void:
	_last_unit = null
	if _units.is_empty():
		return
	_replace([])


## Leaves exactly `units` selected (in that order).
func select_only(units: Array) -> void:
	_replace(units)


## Takes `units` out of the selection; groups keep them.
func remove(units: Array) -> void:
	var gone := {}
	for unit in units:
		if is_instance_valid(unit):
			gone[(unit as Object).get_instance_id()] = true
	var next: Array = []
	for unit in _units:
		if is_instance_valid(unit) and not gone.has(unit.get_instance_id()):
			next.append(unit)
	_replace(next)


func can_select(unit: Variant) -> bool:
	if unit == null or not is_instance_valid(unit) or not unit is Node:
		return false
	if not (unit as Node).is_inside_tree() or not (unit as Node).is_in_group("unit"):
		return false
	if int(unit.get("owner_slot")) != MpKit.local_slot() or MpKit.local_slot() <= 0:
		return false
	return not unit.call("is_dead")


## Left click on a creature (already known to be under the cursor).
func click(unit: Node3D, screen: Vector2, shift: bool, ctrl: bool) -> void:
	if not can_select(unit):
		return
	var now := Time.get_ticks_msec()
	var again := (unit == _last_unit or _last_at.distance_to(screen) < double_click_px) and now - _last_ms <= int(double_click_s * 1000.0)
	if ctrl or again:
		if shift:
			_replace(_merge_front(_units, _same_type_near(unit)))
		else:
			var near := _same_type_near(unit)
			if not near.is_empty():
				_replace(near)
		_last_unit = null
		_last_ms = now
		_last_at = screen
		return
	if shift:
		var next := _units.duplicate()
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


## Rectangle in screen pixels. Own creatures whose body center projects inside it and that
## the camera sees over the terrain; newest first.
func select_rect(from: Vector2, to: Vector2, additive: bool) -> void:
	hide_box()
	var started := Time.get_ticks_usec()
	var rect := Rect2(from, Vector2.ZERO).expand(to)
	var camera := get_viewport().get_camera_3d()
	var picked: Array[Node3D] = []
	if camera:
		for node in get_tree().get_nodes_in_group("unit"):
			if not can_select(node):
				continue
			var center := _center(node)
			if camera.is_position_behind(center) or not rect.has_point(camera.unproject_position(center)):
				continue
			if _hidden_by_ground(camera, center):
				continue
			picked.append(node)
	picked.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.get_instance_id() > b.get_instance_id())
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


func define_group(index: int) -> void:
	_prune()
	_groups[index] = _units.duplicate()
	if index != summon_group:
		for unit in _units:
			(_groups[summon_group] as Array).erase(unit)


func extend_group(index: int) -> void:
	_prune()
	for unit in _units:
		_groups[index] = _push_back(_groups[index], unit)
	if index != summon_group:
		for unit in _units:
			(_groups[summon_group] as Array).erase(unit)
	select_group(index)


func select_group(index: int) -> bool:
	_prune()
	var group: Array = _groups[index]
	if group.is_empty():
		return false
	_replace(group)
	return true


## A creature that was tied to a building leaves the selection and every group (state.d:10408-10410:
## unselect + removeFromGroups). GuardianBond calls it on every peer when its `post_path` fills; the
## creature can be selected again afterwards (canSelect does not exclude guardians).
func drop(unit: Node3D) -> void:
	var was_selected := has(unit)
	_units.erase(unit)
	if is_instance_valid(unit):
		_members.erase(unit.get_instance_id())
	for i in _groups.size():
		(_groups[i] as Array).erase(unit)
	if is_instance_valid(unit):
		_mark([unit], false)
	if was_selected:
		changed.emit(_units.duplicate())


func add_summoned(unit: Node3D) -> void:
	if not can_select(unit):
		return
	_groups[summon_group] = _push_back(_groups[summon_group], unit)
	if not has(unit):
		_replace(_merge_front(_units, [unit]))


func _process(_delta: float) -> void:
	if _prune():
		_mark(_units, true)
		changed.emit(_units.duplicate())


func _replace(next: Array) -> void:
	var fresh: Array[Node3D] = []
	var seen := {}
	for unit in next:
		if max_size > 0 and fresh.size() >= max_size:
			break
		if can_select(unit) and not seen.has(unit.get_instance_id()):
			seen[unit.get_instance_id()] = true
			fresh.append(unit)
	for unit in _units:
		if is_instance_valid(unit) and not seen.has(unit.get_instance_id()):
			_mark([unit], false)
	_units = fresh
	_members = seen
	_mark(_units, true)
	changed.emit(_units.duplicate())


## Drops dead or freed creatures from the selection and the groups. True if the selection shrank.
func _prune() -> bool:
	var before := _units.size()
	var stale := false
	for unit in _units:
		if not can_select(unit):
			stale = true
			break
	if stale:
		var kept: Array[Node3D] = []
		for unit in _units:
			if can_select(unit):
				kept.append(unit)
			else:
				if is_instance_valid(unit):
					_mark([unit], false)
		_units = kept
		_members.clear()
		for unit in _units:
			_members[unit.get_instance_id()] = true
	for i in _groups.size():
		var group: Array = _groups[i]
		for unit in group:
			if not can_select(unit):
				_groups[i] = group.filter(func(member: Variant) -> bool: return can_select(member))
				break
	return _units.size() != before


func _mark(list: Array, on: bool) -> void:
	for unit in list:
		var bar: Node = (unit as Node).get_node_or_null("HealthBar")
		if bar and bar.has_method("set_selected"):
			bar.call("set_selected", on)


## CreatureGroup.addFront for each of `front` (kept in order), dropping the oldest past max_size.
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


## CreatureGroup.addBack: a full group drops its first creature.
func _push_back(group: Array, unit: Node3D) -> Array:
	var result := group.duplicate()
	if result.has(unit):
		return result
	if max_size > 0 and result.size() >= max_size:
		result.remove_at(0)
	result.append(unit)
	return result


## Own creatures within same_type_radius of `unit`, closest first: of the same type that are not
## guardians; for a guardian, the guardians of the same building, whatever their type (selectAll,
## state.d:29884-29896).
func _same_type_near(unit: Node3D) -> Array:
	var tag := str(unit.get("creature_tag"))
	var bond := GuardianBond.of(unit)
	var guarding := bond != null and bond.is_bound()
	var near: Array = []
	for node in get_tree().get_nodes_in_group("unit"):
		if not can_select(node):
			continue
		var other := GuardianBond.of(node)
		var other_guards := other != null and other.is_bound()
		if other_guards != guarding:
			continue
		if guarding:
			if other.post_path != bond.post_path:
				continue
		elif str(node.get("creature_tag")) != tag:
			continue
		if (node as Node3D).global_position.distance_to(unit.global_position) <= same_type_radius:
			near.append(node)
	near.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(unit.global_position) < b.global_position.distance_squared_to(unit.global_position))
	if max_size > 0 and near.size() > max_size:
		near.resize(max_size)
	return near


func _center(unit: Node3D) -> Vector3:
	var visual := unit.get_node_or_null("Tilt/Mesh")
	var height := float(visual.call("body_height")) if visual and visual.has_method("body_height") else 1.8
	return unit.global_position + Vector3.UP * height * 0.5


func _hidden_by_ground(camera: Camera3D, center: Vector3) -> bool:
	if ground == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, center)
	query.collision_mask = 1
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var body: Object = hit.get("collider")
	return body == ground or (body is Node and ground.is_ancestor_of(body))
