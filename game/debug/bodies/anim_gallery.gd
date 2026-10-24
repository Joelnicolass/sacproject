extends Node

## Debug (windowed): contact sheets of the animation of the models, in 3/4 side view. The models of a group are sorted by size and
## cut into sheets of SHEET_SIZE (the big ones together, so each sheet's cell fits its biggest model). A sheet is a grid of cells
## standing on a wall, every model at its true size, turned YAW_DEG toward a camera that frames the whole grid. For every role in
## ROLES_SHOWN that a model of the sheet has, it poses the models at 8 evenly spaced moments of their own clip and saves ONE PNG
## per sheet and role (8 frames, 2 columns x 4 rows), then quits.
##   Godot --path . res://debug/bodies/anim_gallery.tscn -- --anim-gallery=<group> --out=<dir>
## Groups: wizards, creatures_a, creatures_b (the other creatures, split in halves by tag), doctor_npcs (the Sac Doctor,
## peasants and models of your own). Files: <dir>/<group><n>_<role>.png and <dir>/<group>_index.txt (sheet, role -> model=clip tag).
## Headless it lays the first sheet out and stops before the capture (the rig is inert without a renderer). Changes no data.

const ROLES_SHOWN: PackedStringArray = ["idle", "run", "attack", "attack2", "shoot", "cast", "hit_floor", "knock", "death", "fly"]
const MOMENTS := 8
const SHEET_SIZE := 8
const COLUMNS := 4
const YAW_DEG := 32.0
const PITCH_DEG := 8.0
const SHOT := Vector2i(1600, 900)
const GROUPS: PackedStringArray = ["wizards", "creatures_a", "creatures_b", "doctor_npcs"]
## A cell is this much bigger than the biggest bind box of its sheet; the model stands this far above the cell's floor, in cells.
const CELL_MARGIN := 1.2
const FOOT_LIFT := 0.2

@export var rig_scene: PackedScene
@export var cells: Node3D
@export var camera: Camera3D
@export var stage: SubViewport
@export var title: Label3D
@export var sun: DirectionalLight3D

var _group := "wizards"
var _out := "user://anim_gallery"
var _rigs: Array[BodyRig] = []
var _labels: Array[Label3D] = []
var _cell := 1.0
var _floor_material := StandardMaterial3D.new()


func _ready() -> void:
	_floor_material.albedo_color = Color(0.3, 0.27, 0.22)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--anim-gallery="):
			_group = arg.substr(15)
		elif arg.begins_with("--out="):
			_out = arg.substr(6)
	if not GROUPS.has(_group):
		push_error("anim_gallery: unknown group «%s» (%s)" % [_group, ", ".join(GROUPS)])
		get_tree().quit(2)
		return
	var sheets := _sheets(_members(_group))
	print("ANIM GALLERY group %s: %d sheets" % [_group, sheets.size()])
	if not BodyCatalog.loads_meshes():
		_layout(sheets[0] if not sheets.is_empty() else [])
		print("ANIM GALLERY headless: first sheet laid out (%d models, cell %.2f m), capture skipped" % [_rigs.size(), _cell])
		get_tree().quit(0)
		return
	call_deferred("_capture_all", sheets)


## The models of a group that have a scene, sorted by tag.
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


## Biggest side of the bind box of the scene (read from the text: no need to load the model).
func _extent(model: String) -> float:
	var found := RegEx.create_from_string("bind_aabb = AABB\\(([^)]*)\\)").search(FileAccess.get_file_as_string(BodyModel.scene_path(model)))
	var parts := found.get_string(1).split(",") if found != null else PackedStringArray()
	if parts.size() < 6:
		return maxf(float(BodyCatalog.info(model).get("height", 1.0)), 1.0)
	return maxf(maxf(absf(float(parts[3])), absf(float(parts[4]))), absf(float(parts[5])))


## The models sorted from the smallest to the biggest bind box, in sheets of SHEET_SIZE.
func _sheets(models: Array[String]) -> Array:
	var sorted := models.duplicate()
	sorted.sort_custom(func(a: String, b: String) -> bool: return _extent(a) < _extent(b))
	var out: Array = []
	for start in range(0, sorted.size(), SHEET_SIZE):
		out.append(sorted.slice(start, start + SHEET_SIZE))
	return out


func _layout(sheet: Array) -> void:
	for child in cells.get_children():
		child.queue_free()
	_rigs.clear()
	_labels.clear()
	_cell = 1.0
	for model: String in sheet:
		_cell = maxf(_cell, _extent(model) * CELL_MARGIN)
	var columns := mini(COLUMNS, sheet.size())
	var rows := ceili(float(sheet.size()) / float(maxi(columns, 1)))
	for i in sheet.size():
		var middle := Vector3((i % columns - (columns - 1) * 0.5) * _cell, ((rows - 1) * 0.5 - i / columns) * _cell, 0.0)
		var floor_at := middle - Vector3(0.0, _cell * (0.5 - FOOT_LIFT), 0.0)
		var holder := Node3D.new()
		holder.name = sheet[i]
		holder.position = floor_at
		holder.rotation.y = deg_to_rad(YAW_DEG)
		cells.add_child(holder)
		var rig := rig_scene.instantiate() as BodyRig
		rig.transform = BodyCatalog.pose(sheet[i], true, true)
		holder.add_child(rig)
		rig.model = sheet[i]
		_rigs.append(rig)
		var label := Label3D.new()
		label.pixel_size = _cell * 0.075 / 64.0
		label.font_size = 64
		label.outline_size = 14
		label.no_depth_test = true
		label.position = middle + Vector3(0.0, -_cell * (0.5 - FOOT_LIFT * 0.4), 0.2)
		cells.add_child(label)
		_labels.append(label)
		var disc := MeshInstance3D.new()
		disc.mesh = CylinderMesh.new()
		(disc.mesh as CylinderMesh).top_radius = _cell * 0.42
		(disc.mesh as CylinderMesh).bottom_radius = _cell * 0.42
		(disc.mesh as CylinderMesh).height = _cell * 0.01
		disc.material_override = _floor_material
		disc.position = floor_at
		cells.add_child(disc)
	# The camera looks at the grid's middle from the front, a little above; the whole grid (and the title above it) fills the frame.
	var span := Vector2(columns * _cell, rows * _cell)
	camera.size = maxf((span.y + _cell * 0.3) * 1.05, span.x * 9.0 / 16.0 * 1.04)
	var back := 60.0 + _cell * 4.0
	camera.look_at_from_position(Vector3(0.0, sin(deg_to_rad(PITCH_DEG)) * back, cos(deg_to_rad(PITCH_DEG)) * back) + Vector3(0.0, _cell * 0.1, 0.0), Vector3(0.0, _cell * 0.1, 0.0))
	title.position = Vector3(-span.x * 0.5 + _cell * 0.1, span.y * 0.5 + _cell * 0.05, 0.2)
	title.pixel_size = _cell * 0.09 / 64.0
	sun.look_at_from_position(Vector3(-_cell, _cell * 3.0, _cell * 4.0), Vector3(0.0, 0.0, 0.0))


func _capture_all(sheets: Array) -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var index := FileAccess.open(_out.path_join("%s_index.txt" % _group), FileAccess.WRITE)
	for number in sheets.size():
		_layout(sheets[number])
		await get_tree().process_frame
		for role in ROLES_SHOWN:
			var who := _rigs.filter(func(rig: BodyRig) -> bool: return rig.has_role(role))
			if who.is_empty():
				continue
			var path := _out.path_join("%s%d_%s.png" % [_group, number + 1, role])
			(await _sheet(role, number)).save_png(path)
			print("ANIM GALLERY wrote %s (%d models have the role)" % [path, who.size()])
			if index != null:
				index.store_line("%s%d %s: %s" % [_group, number + 1, role, ", ".join(who.map(func(rig: BodyRig) -> String: return "%s=%s" % [rig.model, rig.role_tag(role)]))])
	print("ANIM GALLERY done")
	get_tree().quit(0)


## One contact sheet of `role`: MOMENTS shots of the grid, 2 columns x 4 rows.
func _sheet(role: String, number: int) -> Image:
	var sheet := Image.create(SHOT.x * 2, SHOT.y * 4, false, Image.FORMAT_RGBA8)
	for moment in MOMENTS:
		title.text = "%s %d  %s  %d/%d" % [_group, number + 1, role, moment + 1, MOMENTS]
		for i in _rigs.size():
			var rig := _rigs[i]
			rig.visible = rig.has_role(role)
			_labels[i].visible = rig.visible
			_labels[i].text = "%s  %s" % [rig.model, rig.role_tag(role)]
			if rig.visible:
				rig.pose_at(role, float(rig.role_frames(role) - 1) / maxf(rig.role_framerate(role), 1.0) * float(moment) / float(MOMENTS - 1))
		for _i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var shot := stage.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		shot.resize(SHOT.x, SHOT.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, SHOT), Vector2i(moment % 2 * SHOT.x, moment / 2 * SHOT.y))
	return sheet
