extends Node3D

## RFC-023 023f capture: close shots of the ghost look next to an opaque body, a corpse falling with its death clip and
## fading out, and two fliers. One window run:
##   godot --path game --max-fps 60 --resolution 1280x720 res://debug/bodies/rig023f/rig023f_shots.tscn -- --out=/abs/dir
## The ghost is a Trogg dressed by SeeThroughLook (the look GhostForm gives a wizard) next to another Trogg that stays opaque.

const UNIT := preload("res://scenes/units/unit.tscn")

var _out := ""
var _looks: Array[SeeThroughLook] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	# A script error inside the coroutine would leave the window open forever: this timer always ends it.
	get_tree().create_timer(90.0, true, false, true).timeout.connect(func() -> void:
		push_error("RIG023F_SHOTS timeout")
		get_tree().quit(1))
	_run.call_deferred()


func _process(_delta: float) -> void:
	for look in _looks:
		look.update()


func _unit(tag: String, at: Vector3) -> UnitBody:
	var unit := UNIT.instantiate() as UnitBody
	unit.type = GameData.creature(tag)
	unit.set("owner_slot", 1)
	unit.set("idle_aggro", false)
	add_child(unit)
	unit.set_physics_process(false)
	unit.position = at
	return unit


func _camera(at: Vector3, look_at_point: Vector3) -> void:
	var cam := $Camera as Camera3D
	cam.position = at
	cam.look_at(look_at_point)


func _shot(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(_out.path_join("%s.png" % name))


func _run() -> void:
	await get_tree().process_frame
	var report: PackedStringArray = []
	# 1. A see-through body next to an opaque one (and a third, opaque, behind).
	var solid := _unit("ycro", Vector3(-1.6, 0.0, 0.0))
	var ghost := _unit("ycro", Vector3(1.6, 0.0, 0.0))
	var behind := _unit("raeb", Vector3(0.0, 0.0, -3.5))
	for unit in [solid, ghost, behind]:
		unit.debug_set_clip_state("run")
	await get_tree().create_timer(0.5).timeout
	var look := SeeThroughLook.new(ghost.get_node("Tilt/Mesh") as GeometryInstance3D)
	look.energy_scale = 0.224
	look.set_shadow(false)
	look.set_shadeless(true)
	look.set_transparency(0.64)
	_looks.append(look)
	_camera(Vector3(0.0, 2.6, 6.5), Vector3(0.0, 1.0, 0.0))
	await _shot("ghost_beside_opaque")
	report.append("ghost: solid transparency=%.2f ghost transparency=%.2f meshes=%d" % [
		_mesh_transparency(solid), _mesh_transparency(ghost), look.meshes().size()])
	solid.queue_free()
	ghost.queue_free()
	behind.queue_free()
	_looks.clear()
	await get_tree().process_frame

	# 2. A corpse: the death clip lays it down, then it fades out.
	var dying := _unit("ycro", Vector3(0.0, 0.0, 0.0))
	dying.debug_set_clip_state("idle")
	await get_tree().create_timer(0.4).timeout
	_camera(Vector3(0.0, 2.2, 6.5), Vector3(0.0, 0.7, 0.0))
	dying.debug_clear_clip_state()
	dying.mode = UnitBody.Mode.DEAD
	var corpse := dying.get_node("Corpse")
	report.append("corpse: clip_driven=%s role=%s" % [corpse.get("clip_driven"), (dying.get_node("ClipPose") as ClipPlayback).active_role()])
	await get_tree().create_timer(0.35).timeout
	await _shot("corpse_fall_a")
	await get_tree().create_timer(0.3).timeout
	await _shot("corpse_fall_b")
	await get_tree().create_timer(2.0).timeout
	await _shot("corpse_laid")
	report.append("corpse: settled=%s" % corpse.get("is_settled"))
	corpse.call("dissolve", dying)
	var dissolve_s := float(corpse.get("dissolve_s"))
	var fade_s := float(corpse.get("fade_s"))
	var started := Time.get_ticks_msec()
	var seen := 0.0
	while is_instance_valid(dying) and seen < 0.4:
		await get_tree().process_frame
		seen = _mesh_transparency(dying) if is_instance_valid(dying) else 1.0
	report.append("corpse: fade reached %.2f after %d ms (dissolve %.1f s, fade %.1f s)" % [seen, Time.get_ticks_msec() - started, dissolve_s, fade_s])
	await _shot("corpse_fade_mid")
	report.append("corpse: mid-fade transparency=%.2f" % (_mesh_transparency(dying) if is_instance_valid(dying) else -2.0))
	await get_tree().create_timer(dissolve_s).timeout
	report.append("corpse: removed=%s" % (not is_instance_valid(dying)))

	# 3. Fliers: a hybrid (dragon) in the air and a pure one (hummingbat).
	var dragon := _unit("grdb", Vector3(-4.0, 3.0, 0.0))
	var bat := _unit("tbsh", Vector3(4.0, 2.0, 1.0))
	dragon.debug_set_clip_state("fly")
	bat.debug_set_clip_state("fly")
	_camera(Vector3(0.0, 3.5, 12.0), Vector3(0.0, 2.6, 0.0))
	await get_tree().create_timer(0.6).timeout
	await _shot("fliers_fly")
	dragon.debug_set_clip_state("hover")
	bat.debug_set_clip_state("hover")
	await get_tree().create_timer(0.6).timeout
	await _shot("fliers_hover")
	for unit in [dragon, bat]:
		var info: Dictionary = unit.debug_clip_info()
		report.append("flier %s: role=%s tag=%s" % [unit.creature_tag, info["role"], info["tag"]])
	var file := FileAccess.open(_out.path_join("report.txt"), FileAccess.WRITE)
	file.store_string("\n".join(report) + "\n")
	file.close()
	print("RIG023F_SHOTS done ", _out)
	get_tree().quit()


func _mesh_transparency(unit: Node) -> float:
	var rig := unit.get_node("Tilt/Mesh/Rig") as BodyRig
	var meshes := rig.skinned_meshes()
	return meshes[0].transparency if not meshes.is_empty() else -1.0
