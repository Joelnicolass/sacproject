extends Node

## F28: enemy creatures standing still ahead of the local wizard, to watch spell damage.
## Creature i is `tags[i]` at `spots[i]` = (meters to the wizard's right, meters ahead),
## facing him, on `enemy_slot`, with no aggro (empty target_groups). The label shows their
## health, the body under the screen center (where a click on %View aims) and the hits of the
## last physics frame (a Wrath burst: the direct hit, then the splash), also printed.
## RFC-028b: map buildings (`building_tags` at `building_spots`, same frame) stand among them, to watch
## the splash reach a cactus or a house; their health goes to the label too.

@export var world: Node
@export var unit_scene: PackedScene
@export var arena: Node3D
@export var log_label: Label

@export var tags: PackedStringArray = PackedStringArray(["nmuh", "ycro"])
@export var spots: PackedVector2Array = PackedVector2Array([Vector2(0.0, 40.0), Vector2(0.0, 60.0)])
@export var enemy_slot := 2
## Health they start with, as a share of their maximum (Rainbow's allies stand hurt).
@export_range(0.01, 1.0, 0.01) var start_health_share := 1.0
## The share rises by this per creature, from the first (Rainbow picks the lowest health first).
@export_range(0.0, 0.2, 0.005) var health_share_step := 0.0
@export var building_tags: PackedStringArray = PackedStringArray()
@export var building_spots: PackedVector2Array = PackedVector2Array()
## Empty: the wizard keeps the picked god. Picked like boot does, before the world spawns him.
@export var wizard_god := ""
@export var settle_frames := 8
## RFC-029 029b: each projectile trail (FxTrail) prints `fx_trail <n>` when it leaves the tree: its puffs
## in the first `trail_window_s` from the first one, the same at any fps.
@export var trail_window_s := 2.0

var _units: Array[Node3D] = []
var _aim := ""
var _last := ""
var _last_frame := -1


func _enter_tree() -> void:
	if not wizard_god.is_empty():
		var chosen := WizardPick.new()
		chosen.wizard = SacrificeFlow.pick.wizard
		chosen.god = MatchWire.decode_god(wizard_god)
		SacrificeFlow.set_pick(chosen)


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	world.local_wizard_changed.connect(func(_wizard: Node3D) -> void: _start.call_deferred())
	if world.call("local_wizard"):
		_start.call_deferred()


func _start() -> void:
	var wizard: Node3D = world.call("local_wizard")
	if wizard == null or not _units.is_empty():
		return
	for _frame in settle_frames:
		await get_tree().physics_frame
	var ahead: Vector3 = wizard.call("facing_flat")
	var right := ahead.cross(Vector3.UP)
	for i in mini(tags.size(), spots.size()):
		var at := wizard.global_position + right * spots[i].x + ahead * spots[i].y
		_units.append(_spawn(tags[i], i, at, -ahead))
	for i in mini(building_tags.size(), building_spots.size()):
		var spot := wizard.global_position + right * building_spots[i].x + ahead * building_spots[i].y
		_units.append(_place_building(building_tags[i], i, spot))
	print("blancos %s" % ", ".join(tags))


func _spawn(tag: String, index: int, at: Vector3, facing: Vector3) -> Node3D:
	var unit: Node3D = unit_scene.instantiate()
	unit.name = "%s%d" % [tag.capitalize(), index + 1]
	unit.set("creature_tag", tag)
	unit.set("owner_slot", enemy_slot)
	unit.set("target_groups", PackedStringArray())
	arena.add_child(unit)
	unit.global_position = at
	unit.rotation.y = atan2(facing.x, facing.z)
	unit.get_node("Health").hurt.connect(_on_hurt.bind(unit))
	if start_health_share < 1.0 or health_share_step > 0.0:
		_wound.call_deferred(unit, minf(1.0, start_health_share + health_share_step * float(index)))
	return unit


func _wound(unit: Node3D, share: float) -> void:
	var health := unit.get_node("Health") as Health
	health.current = health.maximum * share


func _place_building(tag: String, index: int, at: Vector3) -> Node3D:
	var building: Node3D = TypeRef.building(tag).scene().instantiate()
	building.name = "%s_%d" % [tag, index + 1]
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 200.0, at + Vector3.DOWN * 200.0)
	query.collision_mask = 1
	var hit := arena.get_world_3d().direct_space_state.intersect_ray(query)
	arena.add_child(building)
	building.global_position = Vector3(at.x, float(hit.position.y) if not hit.is_empty() else at.y, at.z)
	building.get_node("Health").hurt.connect(_on_hurt.bind(building))
	return building


func _on_hurt(amount: float, kind: StringName, _from_slot: int, unit: Node3D) -> void:
	var health := unit.get_node("Health")
	var line := ""
	if amount <= 0.0 and float(health.call("resistance", kind)) <= 0.0:
		line = "%s inmune" % _name_of(unit)
	else:
		line = "dano %s %d vida %d" % [_name_of(unit), roundi(amount), roundi(float(health.get("current")))]
	var frame := Engine.get_physics_frames()
	_last = line if frame != _last_frame else "%s · %s" % [_last, line]
	_last_frame = frame
	print("%s (%s)" % [line, kind])


func _process(_delta: float) -> void:
	_aim = _body_at_center()
	if log_label == null:
		return
	var bars: PackedStringArray = []
	for unit in _units:
		if is_instance_valid(unit):
			var health := unit.get_node("Health")
			bars.append("%s %d/%d" % [_name_of(unit), roundi(float(health.get("current"))), roundi(float(health.get("maximum")))])
	log_label.text = "%s\nmira %s\n%s" % [" · ".join(bars), _aim, _last]


func _body_at_center() -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return ""
	var screen := get_viewport().get_visible_rect().size * 0.5
	var origin := cam.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + cam.project_ray_normal(screen) * 10000.0)
	query.collision_mask = 3
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(query)
	var body := hit.get("collider") as Node3D if not hit.is_empty() else null
	if body == null:
		return "nada"
	var wizard: Node3D = world.call("local_wizard")
	var meters := (hit.position as Vector3).distance_to(wizard.global_position) if wizard else 0.0
	var what := _name_of(body) if body.is_in_group("unit") or body.is_in_group("wizard") else "suelo"
	return "%s a %d m" % [what, roundi(meters)]


func _on_node_added(node: Node) -> void:
	if node is FxTrail:
		var times: Array[int] = []
		(node as FxTrail).puffed.connect(func(_at: Vector3) -> void: times.append(Time.get_ticks_msec()))
		node.tree_exiting.connect(func() -> void: _print_trail(node as FxTrail, times), CONNECT_ONE_SHOT)


func _print_trail(trail: FxTrail, times: Array[int]) -> void:
	if times.is_empty():
		print("fx_trail 0 (%s, sin puffs)" % trail.type_name)
		return
	var limit := times[0] + int(trail_window_s * 1000.0)
	var within := times.filter(func(ms: int) -> bool: return ms < limit).size()
	print("fx_trail %d (%s, %.1f s; vuelo %d puffs en %d ms; %d fps)" % [within, trail.type_name, trail_window_s, times.size(), times[-1] - times[0], Engine.get_frames_per_second()])


func _name_of(unit: Node3D) -> String:
	return str(unit.call("display_name")) if unit.has_method("display_name") else str(unit.name)
