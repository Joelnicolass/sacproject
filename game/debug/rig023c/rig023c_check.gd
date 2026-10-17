extends Node

## RFC-023 023c check (headless or with a window): one unit per creature model, the ClipClock reads, the animator picks
## skeleton or baked, and the roles resolve. Prints one line per model. Not a test of the simulation.
##   godot --headless --path game res://debug/rig023c/rig023c_check.tscn [-- --models=eorc,huma]

const UNIT := preload("res://scenes/world/units/unit.tscn")


func _ready() -> void:
	var only := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--models="):
			only = arg.trim_prefix("--models=").split(",")
	var holder := Node3D.new()
	add_child(holder)
	await get_tree().process_frame
	var seen := {}
	var bad := 0
	for tag: String in GameData._creatures.keys():
		var type := GameData.creature(tag)
		if type == null or seen.has(type.model) or (not only.is_empty() and not only.has(type.model)):
			continue
		seen[type.model] = true
		var unit := UNIT.instantiate() as UnitBody
		unit.creature_tag = tag
		holder.add_child(unit)
		await get_tree().process_frame
		await get_tree().physics_frame
		var anim := unit.get_node("ClipPose") as BodyAnimator
		var roles := UnitClipRoles.for_type(type, type.model)
		var info := unit.debug_clip_info()
		var rig := unit.get_node("Tilt/Mesh/Rig") as BodyRig
		print("%s\t%s\tskeletal=%s\trole=%s\ttag=%s\tfps=%s\trig_loaded=%s\troles=%d" % [
			type.model, tag, anim.is_skeletal(), info.role, info.tag, info.fps, rig.is_loaded(), roles.size()])
		if str(info.role) != "idle" and anim.has_role("idle"):
			bad += 1
		unit.queue_free()
		await get_tree().process_frame
	print("RIG023C_CHECK %s" % ("FAIL (%d)" % bad if bad > 0 else "OK"))
	get_tree().quit(1 if bad > 0 else 0)
