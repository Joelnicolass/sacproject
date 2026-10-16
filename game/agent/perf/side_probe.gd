extends Node
## Agent-only: same-model units of two sides side by side, two shots 0.5 s apart.
@export var world: Node3D
@export var units: Node3D
@export var view_camera: Camera3D
@export var unit_scene: PackedScene

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var hud := world.get_node_or_null("Hud")
	if hud: hud.visible = false
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	var c := Vector2(1545.0, 1340.0)
	var terrain := get_tree().get_first_node_in_group("terrain")
	var i := 0
	for tag in ["ycro", "amuh", "nmuh"]:
		for slot in [1, 2]:
			var u: Node3D = unit_scene.instantiate()
			u.set("creature_tag", tag)
			u.set("owner_slot", slot)
			u.set("idle_aggro", false)
			var x: float = c.x + float(i / 2 - 1) * 3.5 + (slot - 1.5) * 1.2
			var z: float = c.y + (slot - 1.5) * 1.0
			var y := 18.0
			if terrain and terrain.has_method("ground_height"):
				var f: float = terrain.ground_height(x, z)
				y = f if not is_nan(f) else y
			units.add_child(u)
			u.global_position = Vector3(x, y + 0.2, z)
			u.call_deferred("debug_set_clip_state", "run")
			i += 1
	view_camera.global_position = Vector3(c.x, 21.5, c.y - 9.0)
	view_camera.look_at(Vector3(c.x, 19.3, c.y), Vector3.UP)
	for k in 90: await get_tree().process_frame
	var out := "res://agent/out/ptperf/"
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "side_a.png")
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "side_b.png")
	get_tree().quit()
