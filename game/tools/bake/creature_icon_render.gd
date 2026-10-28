class_name CreatureIconRender
extends RefCounted

## The HUD icon of a creature of your own, drawn from its model. A SubViewport with its own world holds the .glb in
## the pose of its idle clip, a camera frames the box of the mesh, and the picture is put on a dark disc with a gold ring, at the size
## of the original's icons (32 x 32, assets/original/ui/icons/). The result goes to assets/custom/icons/<tag>.png, and `link` puts it in the `icon` of the creature's .tres.
## A PNG that already exists there is never overwritten (it may be yours): `force` draws it again.
## It needs a renderer: a headless run has none, so `ensure` says so and writes nothing.

const MODEL_DIR := "res://assets/custom/models/"
const ICON_DIR := "res://assets/custom/icons/"
## Pixels of the icon (the original's) and of the picture it is scaled down from.
const SIZE := 32
const SHOT := 256
const FOV_DEG := 28.0
## The box fills the picture this much (1 = touching the edges).
const FILL := 0.86
## From where the camera looks at the model, in the model's axes (it faces +Z): a little to the side and above.
const VIEW := Vector3(0.45, 0.3, 1.0)
const GOLD := Color8(173, 109, 19)
const BLUE := Color8(54, 76, 160)
const DISC := Color(0.05, 0.045, 0.08, 0.9)


static func path_for(tag: String) -> String:
	return ICON_DIR + tag + ".png"


## The .glb clip the creature rests on: the one behind its `gesture` role, else its `idle` ("" without a library).
static func idle_clip_of(type: CreatureType) -> String:
	if type == null or type.clips == null:
		return ""
	for role: StringName in [&"gesture", &"idle"]:
		if type.clips.has_animation(role):
			return type.clips.get_animation(role).resource_name
	return ""


## Makes assets/custom/icons/<tag>.png if it is missing (or `force`). `host` is a node inside the tree (it holds the viewport for a
## few frames). Returns a line saying what happened.
static func ensure(host: Node, tag: String, idle_clip: String, force := false) -> String:
	var path := path_for(tag)
	if not force and FileAccess.file_exists(path):
		return "kept %s (yours; --icon draws it again)" % path
	var glb := load(MODEL_DIR + tag + ".glb") as PackedScene
	if glb == null:
		return "not drawn: %s%s.glb is not imported" % [MODEL_DIR, tag]
	var image := await render(host, glb, idle_clip)
	if image == null:
		return "not drawn: no renderer here (a headless run has none). Run `Godot --path . --script res://tools/bake/creature_icon.gd -- %s` with a window, or put your own %s" % [tag, path]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ICON_DIR))
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		return "not drawn: cannot write %s (%d)" % [path, error]
	return "wrote %s (%d x %d)" % [path, SIZE, SIZE]


## Puts the PNG of `tag` in the `icon` of data/catalog/creatures/<tag>.tres. Godot has to have imported the PNG first (open the editor or run
## `--import` once); until then it says so and `tools/bake/fill_type_icons.gd` does it later. A creature that already has an icon keeps it.
static func link(tag: String) -> String:
	var type_path := TypeRef.creature_path(tag)
	var type := ResourceLoader.load(type_path, "", ResourceLoader.CACHE_MODE_REPLACE) as CreatureType
	if type == null:
		return "not linked: %s does not exist" % type_path
	if type.icon != null:
		return "icon already set (%s)" % type.icon.resource_path
	var path := path_for(tag)
	if not ResourceLoader.exists(path):
		return "not linked: %s is not imported yet (open the editor or run --import once, then tools/bake/fill_type_icons.gd)" % path
	type.icon = load(path) as Texture2D
	return "linked in %s" % type_path if ResourceSaver.save(type, type_path) == OK else "not linked: cannot save %s" % type_path


## The 32 x 32 icon of the model `glb` in the pose of its `idle_clip`, or null without a renderer.
static func render(host: Node, glb: PackedScene, idle_clip: String) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SHOT, SHOT)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)

	var model := glb.instantiate() as Node3D
	viewport.add_child(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var player := players[0] as AnimationPlayer
		var clip := &""
		if player.has_animation(idle_clip):
			clip = StringName(idle_clip)
		elif not player.get_animation_list().is_empty():
			clip = StringName(player.get_animation_list()[0])
		if clip != &"":
			player.play(clip)
			player.seek(0.0, true)
			player.pause()

	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.82, 0.84, 0.95)
	environment.ambient_light_energy = 0.6
	var camera := Camera3D.new()
	camera.environment = environment
	camera.fov = FOV_DEG
	viewport.add_child(camera)
	var light := DirectionalLight3D.new()
	light.light_energy = 1.2
	viewport.add_child(light)

	var box := _box(model)
	var center := box.get_center()
	var direction := VIEW.normalized()
	camera.look_at_from_position(center + direction * _distance(box, direction, FOV_DEG), center, Vector3.UP)
	light.look_at_from_position(center + Vector3(-0.7, 1.0, 0.9) * 5.0, center, Vector3.UP)

	var tree := host.get_tree()
	await tree.process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var shot := viewport.get_texture().get_image()
	viewport.queue_free()
	if shot == null or shot.is_empty():
		return null
	shot.convert(Image.FORMAT_RGBA8)
	shot.fix_alpha_edges()
	shot.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	return _framed(shot)


## The box of the skinned meshes of `root` (their rest pose), in the viewport's world.
static func _box(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var moved := mesh.global_transform * mesh.mesh.get_aabb()
		box = moved if first else box.merge(moved)
		first = false
	return box


## How far from the center of `box` a camera looking along `direction` (from the center) has to be for the whole box to be
## inside the picture, FILL of it. The corners are projected on the camera's axes: one by one is exact for any box.
static func _distance(box: AABB, direction: Vector3, fov_deg: float) -> float:
	var basis := Basis.looking_at(-direction, Vector3.UP)
	var reach := tan(deg_to_rad(fov_deg) * 0.5) * FILL
	var distance := 0.1
	for corner in 8:
		var offset := box.get_endpoint(corner) - box.get_center()
		var local := basis.inverse() * offset
		# The camera looks down -Z of its basis: a corner `local.z` toward it is closer by that much.
		distance = maxf(distance, local.z + maxf(absf(local.x), absf(local.y)) / reach)
	return distance


## The portrait over a dark disc with the ring of the original's icons (gold outside, a thin blue one inside).
static func _framed(portrait: Image) -> Image:
	var out := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var middle := (SIZE - 1) * 0.5
	for y in SIZE:
		for x in SIZE:
			var d := Vector2(x - middle, y - middle).length()
			var color := Color(0.0, 0.0, 0.0, 0.0)
			var disc := clampf(15.0 - d, 0.0, 1.0)
			if disc > 0.0:
				color = Color(DISC.r, DISC.g, DISC.b, DISC.a * disc)
			var blue := clampf(1.0 - absf(d - 12.4) / 0.9, 0.0, 1.0) * 0.55
			if blue > 0.0:
				color = color.blend(Color(BLUE.r, BLUE.g, BLUE.b, blue))
			var gold := clampf(1.0 - absf(d - 14.0) / 1.3, 0.0, 1.0)
			if gold > 0.0:
				color = color.blend(Color(GOLD.r, GOLD.g, GOLD.b, gold))
			out.set_pixel(x, y, color.blend(portrait.get_pixel(x, y)))
	return out
