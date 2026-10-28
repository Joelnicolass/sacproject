@tool
class_name MapBuilding
extends StaticBody3D

## A building of the map (house, fence, tree, gravestone) you drag into a map and move with the gizmo. Its parts are saved
## children of `Visuals` («Hijos editables»); the box of `Collision` holds them and is the melee reach and the splash, and at play
## the body is that box minus `inset_m` on x and z. A flat one has no box body, only its `trunk` (a tree; server too, navmesh).
## owner_slot 0 is the neutral side 31. Joins `map_building`, `structure` (unless flat) and `shelter` while it shelters. It owns
## «fallen» (no souls, no collision) but draws and sounds nothing: children listen to `damaged` / `destroyed` (StructureBreak, BuildingRuin).

## Every peer: the health went down (fraction_left = current / maximum, 0..1). Emitted once at 0, never after.
signal damaged(fraction_left: float)
## Every peer, once: the health reached 0. Collision and groups are already off.
signal destroyed(building: MapBuilding)

const GROUP := &"map_building"
const SHELTER_GROUP := &"shelter"
## Standing buildings that block, can be attacked and count as structures (flat ones are not).
const STRUCTURE_GROUP := &"structure"

@export var type: BuildingType:
	set(value):
		type = value
		update_configuration_warnings()
@export var max_health_override := 0.0
@export var owner_slot := 0
## Units pass the eaves: the body is the box of `Collision` this much (m) narrower on every side of x and z.
@export_range(0.0, 5.0, 0.05, "suffix:m") var inset_m := 0.5
@export_group("Parts")
@export var visuals: Node3D
@export var health: Health
@export var collision: CollisionShape3D
## What stops the bodies when the building flattens the ground: a CylinderShape3D child sized to the trunk with the gizmo.
@export var trunk: CollisionShape3D
@export var sync: MultiplayerSynchronizer
@export var health_bar: UnitHealthBar
@export_tool_button("Ajustar a las partes", "Reload") var fit := _fit_to_parts

var max_health := 0.0
var shelter := false
## Derived from `type`: the id the network and the old maps use (jhut). Read-only.
var tag: String:
	get:
		return type.tag if type != null else ""

var _box := AABB(Vector3(-2.0, 0.0, -2.0), Vector3(4.0, 4.0, 4.0))
var _gone := false
var _last_health := 0.0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if type == null:
		warnings.append("Asigná `type` (data/buildings/<nombre>.tres).")
	if collision == null or not collision.shape is BoxShape3D:
		warnings.append("`collision` necesita un BoxShape3D: la caja que encierra las partes.")
	return warnings


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(GROUP)
	var flat := type != null and type.flattens_ground
	max_health = max_health_override if max_health_override > 0.0 else (type.max_health if type != null else 0.0)
	shelter = type != null and type.shelters_peasants
	if not flat:
		add_to_group(STRUCTURE_GROUP)
	if shelter:
		add_to_group(SHELTER_GROUP)
	## A tower on a client already has the maximum its synchronizer sent with the spawn: setting it again would erase the damage.
	if max_health > 0.0 and health.maximum <= 0.0:
		health.setup(max_health)
	elif max_health <= 0.0:
		health.maximum = 0.0
		if sync != null:
			sync.queue_free()
	_read_body(flat)
	_last_health = health.current
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


## What a blow needs to know of its target (MeleeRules.profile_of): a reach as wide as the box.
func melee_profile() -> Dictionary:
	var c := _box.get_center()
	var reach := maxf(absf(c.x) + _box.size.x * 0.5, absf(c.z) + _box.size.z * 0.5)
	return {"evasion": 0.0, "resistance": 1.0, "reach": reach, "height": _box.position.y + _box.size.y}


## The box of `Collision` is the box of the parts; the body is that box smaller by the inset. Flattening the ground: no box.
func _read_body(flat: bool) -> void:
	if flat:
		collision.disabled = true
		collision_layer = 1 if trunk != null else 0
		return
	var parts := collision.shape as BoxShape3D
	if parts == null:
		return
	_box = AABB(collision.position - parts.size * 0.5, parts.size)
	var body := BoxShape3D.new()
	body.size = BuildingFit.body_size(_box, inset_m)
	collision.shape = body


## Editor button: the box of `Collision` becomes the box that holds every part (a new BoxShape3D, saved with the scene).
func _fit_to_parts() -> void:
	var parts := BuildingFit.parts_box(visuals)
	if parts.size == Vector3.ZERO or not collision.shape is BoxShape3D:
		push_warning("%s: needs a MeshInstance3D part with a mesh to measure and a BoxShape3D in `collision`." % name)
		return
	var shape := collision.shape.duplicate() as BoxShape3D
	shape.size = parts.size
	collision.shape = shape
	collision.position = parts.get_center()
	update_configuration_warnings()


func _on_health_changed(current: float, maximum: float) -> void:
	if not _gone and maximum > 0.0 and current < _last_health:
		damaged.emit(clampf(current / maximum, 0.0, 1.0))
	_last_health = current
	if _gone or not health.is_dead():
		return
	_gone = true
	remove_from_group(SHELTER_GROUP)
	remove_from_group(STRUCTURE_GROUP)
	collision_layer = 0
	collision.set_deferred("disabled", true)
	if trunk != null:
		trunk.set_deferred("disabled", true)
	destroyed.emit(self)
