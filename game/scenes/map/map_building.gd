@tool
class_name MapBuilding
extends StaticBody3D

## A building of the map (house, fence, tree, gravestone), placed with the gizmo. Its BuildingType says what it looks like
## (a scene with the parts, never saved in the map), how much it takes to destroy it and whether peasants hide in it.
## A destroyed building gives no souls and shows its ruin on every peer. owner_slot 0 is the neutral side 31.
## Joins `map_building`, `structure` (unless it flattens the ground) and, while it shelters, `shelter`.
## Does not draw the parts nor measure the box: the type's scene and its BuildingFootprint do.

signal destroyed(building: MapBuilding)

const GROUP := &"map_building"
const SHELTER_GROUP := &"shelter"

@export var building: BuildingType:
	set(value):
		building = value
		if is_node_ready():
			_show_parts()
@export var max_health_override := 0.0
@export var owner_slot := 0
@export var visuals: Node3D
@export var health: Health
@export var collision: CollisionShape3D
@export var sync: MultiplayerSynchronizer
@export var health_bar: UnitHealthBar

var max_health := 0.0
var shelter := false
## Derived from `building`; setting it looks the type up (debug scenes). The reference is what is saved.
var tag: String:
	get:
		return building.tag if building != null else ""
	set(value):
		building = TypeRef.building(value)

var _box := AABB(Vector3(-2.0, 0.0, -2.0), Vector3(4.0, 4.0, 4.0))
var _gone := false
var _footprint: BuildingFootprint
var _parts: Node3D


func _get_configuration_warnings() -> PackedStringArray:
	var complete := visuals != null and health != null and collision != null and building != null and building.scene != null
	return PackedStringArray() if complete else PackedStringArray(["Asigná visuals, health, collision y un edificio con escena."])


func _ready() -> void:
	_show_parts()
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	var flat := building != null and building.flattens_ground
	max_health = max_health_override if max_health_override > 0.0 else (building.max_health if building != null else 0.0)
	shelter = building != null and building.shelters_peasants
	if not flat:
		add_to_group(&"structure")
	if shelter:
		add_to_group(SHELTER_GROUP)
	if max_health > 0.0:
		health.setup(max_health)
	else:
		health.maximum = 0.0
		if sync != null:
			sync.queue_free()
	_shape_collision(flat)
	health.changed.connect(_on_health_changed)
	if health_bar != null:
		health_bar.bind(health, owner_slot)
		health_bar.position = Vector3(_box.get_center().x, 0.0, _box.get_center().z)
		health_bar.place_above(_box.position.y + _box.size.y)


func is_destroyed() -> bool:
	return _gone


func is_sheltering() -> bool:
	return shelter and not _gone


func is_indestructible() -> bool:
	return max_health <= 0.0


## The box of the parts in the building's frame, before the inset (melee reach, splash damage).
func hit_box() -> AABB:
	return _box


## What a blow needs to know of its target (MeleeAttack.profile_of): a reach as wide as the box.
func melee_profile() -> Dictionary:
	var c := _box.get_center()
	var reach := maxf(absf(c.x) + _box.size.x * 0.5, absf(c.z) + _box.size.z * 0.5)
	return {"evasion": 0.0, "resistance": 1.0, "reach": reach, "height": _box.position.y + _box.size.y}


## The type's scene goes under `visuals` as an internal child (never saved); its footprint gives the box.
func _show_parts() -> void:
	update_configuration_warnings()
	if _parts != null:
		_parts.queue_free()
	_parts = null
	_footprint = null
	if visuals == null or building == null or building.scene == null:
		return
	_parts = building.scene.instantiate() as Node3D
	visuals.add_child(_parts, false, Node.INTERNAL_MODE_FRONT)
	for child in _parts.get_children():
		if child is BuildingFootprint:
			_footprint = child


func _shape_collision(flat: bool) -> void:
	if flat:
		collision.disabled = true
		collision_layer = 0
		return
	if _footprint != null:
		_box = _footprint.hit_box
	var shape := BoxShape3D.new()
	shape.size = _footprint.body_size() if _footprint != null else _box.size
	collision.shape = shape
	collision.position = _box.get_center()


func _on_health_changed(_current: float, _maximum: float) -> void:
	if _gone or not health.is_dead():
		return
	_gone = true
	remove_from_group(SHELTER_GROUP)
	remove_from_group(&"structure")
	collision_layer = 0
	collision.set_deferred("disabled", true)
	visuals.visible = false
	if building != null and building.ruin_scene != null:
		add_child(building.ruin_scene.instantiate(), false, Node.INTERNAL_MODE_BACK)
	destroyed.emit(self)
