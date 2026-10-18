class_name MapBuilding
extends StaticBody3D

## A building of the map (RFC-024 addendum 1, 024b2): the houses, fences and decorations of the NTTS. Its
## BLDG (assets/original/data/buildings.json, tools/export_stats.py buildings) says its components (the models), its
## maximum health and whether peasants shelter in it (bit 15). With max health > 0 it has a Health and can
## be destroyed; with 0 it is indestructible (the console says so once per tag). A destroyed building gives no
## souls (sacengine destroy only adds the collapse, state.d:8376-8380): it just goes away on every peer.
## owner_slot 0 is the neutral side 31: nobody's enemy (SideRelations), but it can be attacked on purpose.
## It joins the groups `structure` (cursor, vision and attack orders treat it as a building), `map_building`
## and, while it shelters, `shelter`. A model that was not baked shows the gray placeholder and says so.

signal destroyed(building: MapBuilding)

const GROUP := &"map_building"
const SHELTER_GROUP := &"shelter"
const BUILDINGS_PATH := OriginalAssets.DATA_DIR + "buildings.json"

## BLDG tag, in the order the WAD names use (jhut, jwg1, jcc1).
@export var tag := ""
## 0 = take it from the BLDG. Debug scenes set it to test fast.
@export var max_health_override := 0.0
@export var owner_slot := 0
## Turn about the vertical axis, degrees, as the NTTS stores it (positive turns Godot's y backwards). Applied in _ready
## with the same operation the map loader used (RFC-035 R2), so the stored rotation never differs by an ULP. 0 leaves
## the transform as the scene or the code that added the node set it.
@export var facing_deg := 0.0
@export_group("Collision")
## The body is the box of the models, smaller by this much (m) on every side, so units pass the eaves.
## Decision of the port (not sacengine): a little smaller than the box so units pass the eaves.
@export var collision_inset := 0.5
@export_group("Parts")
@export var visuals: Node3D
@export var health: Health
@export var collision: CollisionShape3D
## Sends the health of a destructible building to the clients; an indestructible one frees it.
@export var sync: MultiplayerSynchronizer
## RFC-028b: the bar StructureInspector shows over the box when the building is clicked (unit_health_bar.tscn).
@export var health_bar: Node3D

## Read from the BLDG when the node is ready.
var max_health := 0.0
var shelter := false
## The BLDG has the ground flag: the land is changed under it, and it has no body of its own.
var ground := false

static var _bldgs: Dictionary = {}
static var _bldgs_loaded := false
static var _announced: Dictionary = {}

## The box of the models in the building's frame (set with the collision), for melee reach.
var _box := AABB(Vector3(-2.0, 0.0, -2.0), Vector3(4.0, 4.0, 4.0))
var _gone := false
var _missing := PackedStringArray()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if visuals == null or health == null or collision == null:
		warnings.append("Asigná visuals, health y collision.")
	return warnings


func _ready() -> void:
	if facing_deg != 0.0:
		rotation.y = -deg_to_rad(facing_deg)
	add_to_group(GROUP)
	var record := bldg(tag)
	if record.is_empty():
		push_warning("MapBuilding: el BLDG «%s» no está en assets/original/data/buildings.json; relleno gris." % tag)
	max_health = max_health_override if max_health_override > 0.0 else float(record.get("max_health", 0.0))
	shelter = bool(record.get("shelter", false))
	ground = bool(record.get("ground", false))
	## A ground decoration (bld*, bon*, jeg*) is no building to attack or to keep a Manalith away from.
	if not ground:
		add_to_group(&"structure")
	if shelter:
		add_to_group(SHELTER_GROUP)
	if max_health > 0.0:
		health.setup(max_health)
	else:
		health.maximum = 0.0
		if not _announced.has(tag):
			_announced[tag] = true
			print("edificio %s: vida 0 en su BLDG, es indestructible" % tag)
	if max_health <= 0.0 and sync != null:
		sync.queue_free()
	_build_visuals(record)
	health.changed.connect(_on_health_changed)
	_place_bar()


## The BLDG record of `name`, {} when the cache has none.
static func bldg(name: String) -> Dictionary:
	if not _bldgs_loaded:
		_bldgs_loaded = true
		if FileAccess.file_exists(BUILDINGS_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUILDINGS_PATH))
			if parsed is Dictionary:
				_bldgs = parsed
	return _bldgs.get(name, {})


func is_destroyed() -> bool:
	return _gone


func is_sheltering() -> bool:
	return shelter and not _gone


func is_indestructible() -> bool:
	return max_health <= 0.0


## The hit box (sacengine hitbox): the box of the models in the building's frame, before `collision_inset`.
## Melee reach and splash damage (SplashDamage.box_distance) measure against it.
func hit_box() -> AABB:
	return _box


## What a blow needs to know of its target (MeleeAttack.profile_of): no evasion, plain resistance and a reach as
## wide as the box, so a creature stopped by the collision still touches it.
func melee_profile() -> Dictionary:
	var center := _box.position + _box.size * 0.5
	var half := maxf(absf(center.x) + _box.size.x * 0.5, absf(center.z) + _box.size.z * 0.5)
	return {"evasion": 0.0, "resistance": 1.0, "reach": half, "height": _box.position.y + _box.size.y}


## One mesh per component of the BLDG (offset and facing as the BLDG says), then a box for the body. The box
## comes from the baked sizes (BodyCatalog.info "box"), not from the mesh, so a headless server (no meshes)
## shapes the same collision as a client. Sac axes (x, y, z up) are Godot (x, z, y); a facing in degrees
## about the sac z turns Godot's y backwards.
func _build_visuals(record: Dictionary) -> void:
	var components: Array = record.get("components", [{"tag": tag, "x": 0.0, "y": 0.0, "z": 0.0, "facing": 0.0}])
	var box := AABB()
	var any := false
	for component: Dictionary in components:
		var model := str(component.get("tag", ""))
		if model.is_empty():
			continue
		var holder := Node3D.new()
		holder.name = "Part_%s" % model
		holder.position = Vector3(float(component.get("x", 0.0)), maxf(float(component.get("z", 0.0)), 0.0), float(component.get("y", 0.0)))
		holder.rotation.y = -deg_to_rad(float(component.get("facing", 0.0)))
		var part := BodyVisual.new()
		part.name = "Mesh"
		part.stand_on_feet = false
		part.model = model
		holder.add_child(part)
		visuals.add_child(holder)
		if not BodyCatalog.has_model(model):
			_missing.append(model)
			continue
		var raw: Array = BodyCatalog.info(model).get("box", [])
		if raw.size() == 6:
			var local := AABB(Vector3(raw[0], raw[1], raw[2]), Vector3(raw[3], raw[4], raw[5]))
			var placed: AABB = holder.transform * BodyCatalog.pose(model, false) * local
			box = placed if not any else box.merge(placed)
			any = true
	if not _missing.is_empty() and BodyCatalog.loads_meshes():
		push_warning("MapBuilding %s: sin modelo horneado de %s; se muestra el relleno." % [tag, ", ".join(_missing)])
	_shape_collision(box, any)


func _shape_collision(box: AABB, has_box: bool) -> void:
	if ground:
		collision.disabled = true
		collision_layer = 0
		return
	if not has_box:
		box = AABB(Vector3(-2.0, 0.0, -2.0), Vector3(4.0, 4.0, 4.0))
	_box = box
	var shape := BoxShape3D.new()
	var inset := collision_inset if has_box else 0.0
	shape.size = Vector3(maxf(box.size.x - 2.0 * inset, 0.5), maxf(box.size.y, 0.5), maxf(box.size.z - 2.0 * inset, 0.5))
	collision.shape = shape
	collision.position = box.position + box.size * 0.5


## The bar over the middle of the box, `lift` above its top; it stays hidden until inspected.
func _place_bar() -> void:
	if health_bar == null:
		return
	health_bar.call("bind", health, owner_slot)
	var center := _box.position + _box.size * 0.5
	health_bar.position = Vector3(center.x, 0.0, center.z)
	health_bar.call("place_above", _box.position.y + _box.size.y)


## Every peer: the server's Health reaches the clients through the synchronizer.
func _on_health_changed(_current: float, _maximum: float) -> void:
	if _gone or not health.is_dead():
		return
	_gone = true
	remove_from_group(SHELTER_GROUP)
	remove_from_group(&"structure")
	collision_layer = 0
	collision.set_deferred("disabled", true)
	visuals.visible = false
	destroyed.emit(self)
	print("edificio %s destruido (sin almas)" % tag)
