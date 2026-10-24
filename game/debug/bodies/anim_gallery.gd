extends Node

## Debug (windowed): contact sheets of the animation of a group of models. It lays the group out in a grid, under a fixed
## orthographic camera and one light, and for every role in ROLES_SHOWN that someone of the group has it poses all the
## models at 8 evenly spaced moments of their own clip and saves ONE PNG per role (8 frames, 2 columns x 4 rows), then quits.
##   Godot --path . res://debug/bodies/anim_gallery.tscn -- --anim-gallery=<group> --out=<dir>
## Groups: wizards, creatures_a, creatures_b (the other creatures, split in halves by tag), doctor_npcs (the Sac Doctor,
## peasants and models of your own). Files: <dir>/<group>_<role>.png and <dir>/<group>_index.txt (cell -> model, clip tag).
## Headless it lays the grid out and stops before the capture (the rig is inert without a renderer). Changes no data.

const ROLES_SHOWN: PackedStringArray = ["idle", "run", "attack", "cast", "shoot", "death", "knock", "fly"]
const MOMENTS := 8
const CELL := Vector2(3.6, 3.4)
const SHOT := Vector2i(1600, 900)
const MAX_COLUMNS := 7
const GROUPS: PackedStringArray = ["wizards", "creatures_a", "creatures_b", "doctor_npcs"]

@export var rig_scene: PackedScene
@export var cells: Node3D
@export var camera: Camera3D
@export var stage: SubViewport
@export var title: Label3D

var _group := "wizards"
var _out := "user://anim_gallery"
var _rigs: Array[BodyRig] = []
var _models: Array[String] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--anim-gallery="):
			_group = arg.substr(15)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
	if not GROUPS.has(_group):
		push_error("anim_gallery: unknown group «%s» (%s)" % [_group, ", ".join(GROUPS)])
		get_tree().quit(2)
		return
	_models = _members(_group)
	_layout()
	print("ANIM GALLERY group %s: %d models" % [_group, _models.size()])
	if not BodyCatalog.loads_meshes():
		print("ANIM GALLERY headless: grid laid out, capture skipped")
		get_tree().quit(0)
		return
	call_deferred("_capture_all")


## The models of a group that have a scene, sorted.
func _members(group: String) -> Array[String]:
	var owners := AnimExpect.owners()
	var rest: Array[String] = []
	var picked: Array[String] = []
	var tags: Array = owners.keys()
	tags.sort()
	for model: String in tags:
		if not BodyModel.exists(model):
			continue
		var kinds: Array = (owners[model] as Array).map(func(o: Dictionary) -> String: return o["kind"])
		var own := FileAccess.get_file_as_string(BodyModel.scene_path(model)).contains("res://assets/custom/")
		var bucket := "wizards" if kinds.has("wizard") else ("doctor_npcs" if own or kinds.has("doctor") or kinds.has("peasant") else "creatures")
		if bucket == group:
			picked.append(model)
		elif bucket == "creatures" and group.begins_with("creatures"):
			rest.append(model)
	if group.begins_with("creatures"):
		var half := (rest.size() + 1) / 2
		return rest.slice(0, half) if group == "creatures_a" else rest.slice(half)
	return picked


func _layout() -> void:
	var columns := mini(MAX_COLUMNS, _models.size())
	var rows := ceili(float(_models.size()) / float(maxi(columns, 1)))
	for i in _models.size():
		var model := _models[i]
		var info := BodyCatalog.info(model)
		var fit := minf(CELL.y * 0.62 / maxf(float(info.get("height", 1.0)), 0.01), CELL.x * 0.4 / maxf(float(info.get("reach", 0.5)), 0.01))
		var cell := Node3D.new()
		cell.name = model
		cell.position = Vector3((i % columns - (columns - 1) * 0.5) * CELL.x, 0.0, (i / columns - (rows - 1) * 0.5) * CELL.y)
		cell.scale = Vector3.ONE * fit
		cells.add_child(cell)
		var rig := rig_scene.instantiate() as BodyRig
		rig.transform = BodyCatalog.pose(model, true, true)
		cell.add_child(rig)
		rig.model = model
		_rigs.append(rig)
		var label := Label3D.new()
		label.text = model
		label.pixel_size = 0.006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(cell.position.x, 0.0, cell.position.z + CELL.y * 0.42)
		cells.add_child(label)
	var width := columns * CELL.x + 1.0
	var depth := rows * CELL.y + 1.5
	# The camera looks 30 degrees down: the depth of the grid shows at half its length, a model at 0.87 of its height.
	camera.size = maxf(depth * 0.5 + 4.0, width * 9.0 / 16.0 + 0.5)
	camera.position = Vector3(0.0, 0.5, 0.866) * (camera.size * 2.0 + 10.0)
	title.position = Vector3(-width * 0.5 + 0.5, 0.2, -depth * 0.5)


func _capture_all() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var index := FileAccess.open(_out.path_join("%s_index.txt" % _group), FileAccess.WRITE)
	for role in ROLES_SHOWN:
		var who := _rigs.filter(func(rig: BodyRig) -> bool: return rig.has_role(role))
		if who.is_empty():
			continue
		var sheet := Image.create(SHOT.x * 2, SHOT.y * 4, false, Image.FORMAT_RGBA8)
		for moment in MOMENTS:
			title.text = "%s  %s  %d/%d" % [_group, role, moment + 1, MOMENTS]
			for rig in _rigs:
				rig.visible = rig.has_role(role)
				if rig.visible:
					var length := float(rig.role_frames(role) - 1) / maxf(rig.role_framerate(role), 1.0)
					rig.pose_at(role, length * float(moment) / float(MOMENTS - 1))
			for _i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var shot := stage.get_texture().get_image()
			shot.convert(Image.FORMAT_RGBA8)
			shot.resize(SHOT.x, SHOT.y, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, SHOT), Vector2i(moment % 2 * SHOT.x, moment / 2 * SHOT.y))
		var path := _out.path_join("%s_%s.png" % [_group, role])
		sheet.save_png(path)
		print("ANIM GALLERY wrote %s (%d models have the role)" % [path, who.size()])
		if index != null:
			index.store_line("%s: %s" % [role, ", ".join(who.map(func(rig: BodyRig) -> String: return "%s=%s" % [rig.model, rig.role_tag(role)]))])
	print("ANIM GALLERY done")
	get_tree().quit(0)
