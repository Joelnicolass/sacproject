extends SubViewportContainer

const _OBJ_MESH := preload("res://scenes/world/wizard.gd")

@export var bodies_dir: String = "res://cache/look/bodies"
@export var spin_speed: float = 0.5
@export var model_height: float = 2.0
@export var model_rotation: Vector3 = Vector3.ZERO

@onready var _pivot: Node3D = %Pivot

var _shown: Dictionary = {}
var _model: String = ""


func _process(delta: float) -> void:
	_pivot.rotate_y(spin_speed * delta)


func show_model(model: String) -> void:
	if model == _model:
		return
	_model = model
	for key: String in _shown:
		(_shown[key] as Node3D).visible = key == model
	if _shown.has(model) or model.is_empty():
		return
	var visual := _build(model)
	if visual == null:
		return
	_pivot.add_child(visual)
	_fit(visual)
	_shown[model] = visual


func _build(model: String) -> MeshInstance3D:
	var library: Variant = get_tree().root.get_node_or_null("BodyLibrary")
	if library != null and library.has_method("mesh"):
		var baked: Variant = library.mesh(model)
		if baked is Mesh:
			var instance := MeshInstance3D.new()
			instance.mesh = baked
			return instance
	var path := "%s/%s/%s.obj" % [bodies_dir, model, model]
	if not FileAccess.file_exists(path):
		return null
	var visual := MeshInstance3D.new()
	visual.set_script(_OBJ_MESH)
	visual.set("cache_path", path)
	visual.set("missing_message", "")
	return visual


func _fit(visual: MeshInstance3D) -> void:
	if visual.mesh == null:
		return
	var turn := Basis.from_euler(model_rotation)
	var fix: Array = BodyLibrary.info(_model).get("upright_fix", [0.0, 0.0, 0.0])
	turn = turn * Basis.from_euler(Vector3(float(fix[0]), float(fix[1]), float(fix[2])) * PI / 180.0)
	var box: AABB = Transform3D(turn, Vector3.ZERO) * visual.mesh.get_aabb()
	if box.size.y <= 0.001:
		return
	var factor := model_height / box.size.y
	var center := box.get_center() * factor
	visual.transform = Transform3D(turn.scaled(Vector3.ONE * factor), Vector3(-center.x, -box.position.y * factor, -center.z))
