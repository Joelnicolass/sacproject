extends SceneTree

## Disposable spike (055a-5 s0): can a ragdoll hang from one bone while its model travels at running speed?
## Variant A: every bone simulates EXCEPT the anchor (the root body, no joint), which keeps following the frozen pose.
## Variant B: every bone simulates and an invisible AnimatableBody3D `Hook` holds the anchor through a locked Generic6DOFJoint3D `Pin`.
## Both move the model 11 m/s along X for 2 s, stop it, and measure each physics tick until 5 s after the stop.
## Per variant it prints: SPIKE A|B PASS|FAIL anchor_err_max=<m> stretch_max=<r> speed3s=<m/s> extent=<r> nan=<bool>
## Criterion: anchor_err <= 0.02, stretch <= 1.3, speed3s < 0.5 (max bone speed from 3 s to 5 s after the stop), extent < 2.0
## (bounding size of all bones over the model height), no NaN. It changes nothing on disk.
##
## Run headless (one process per variant so each starts clean; the orchestrator runs these):
##   godot_run.sh Godot --headless --path . --script res://debug/bodies/hang_spike.gd -- a
##   godot_run.sh Godot --headless --path . --script res://debug/bodies/hang_spike.gd -- b
##   godot_run.sh Godot --headless --path . --script res://debug/bodies/hang_spike.gd           (runs a and b as child processes, prints SPIKE CHOICE A|B|NONE)

const MODEL_SCENE := "res://scenes/bodies/models/trogg_model.tscn"
const SPEED_MPS := 11.0
const MOVE_S := 2.0
const MEASURE_AFTER_STOP_S := 5.0
const SPEED_WINDOW_FROM_S := 3.0
const TIMEOUT_S := 120.0
const ANCHOR_ERR_MAX_M := 0.02
const STRETCH_MAX := 1.3
const SPEED_MAX_MPS := 0.5
const EXTENT_MAX := 2.0

var _variant := ""


func _initialize() -> void:
	_variant = "".join(OS.get_cmdline_user_args()).to_lower()
	var limit := TIMEOUT_S if _variant != "" else TIMEOUT_S * 2.0
	create_timer(limit).timeout.connect(_on_timeout)
	if _variant in ["a", "b", "c", "d", "e", "f", "g", "h", "i"]:
		_run_variant()
	else:
		_run_all()


func _on_timeout() -> void:
	print("SPIKE %s FAIL timeout" % _variant.to_upper())
	quit(1)


func _run_all() -> void:
	var lines := {}
	for v: String in ["a", "b"]:
		var out: Array = []
		OS.execute(OS.get_executable_path(), [
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://debug/bodies/hang_spike.gd", "--", v], out, true)
		for chunk in out:
			for line: String in str(chunk).split("\n"):
				if line.begins_with("SPIKE "):
					print(line)
					lines[v] = line
	var choice := "NONE"
	if str(lines.get("a", "")).begins_with("SPIKE A PASS"):
		choice = "A"
	elif str(lines.get("b", "")).begins_with("SPIKE B PASS"):
		choice = "B"
	print("SPIKE CHOICE %s" % choice)
	quit(0)


func _run_variant() -> void:
	await process_frame
	var holder := Node3D.new()
	root.add_child(holder)
	var model: Node3D = (load(MODEL_SCENE) as PackedScene).instantiate()
	holder.add_child(model)
	if _variant == "g" or _variant == "h":
		## G (and H): the glb instance turned 180 degrees instead of mirrored on z (det +1). Tests whether the reflection breaks the joints.
		var glb := model.get_node_or_null("Model") as Node3D
		if glb != null:
			print("SPIKE G detail model_det_before=%.3f" % glb.transform.basis.determinant())
			glb.transform = Transform3D(Basis(Vector3.UP, PI), glb.transform.origin)
	await process_frame
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var sim: PhysicalBoneSimulator3D = skeleton.get_node("Ragdoll")
	var bodies := {}
	var anchor: PhysicalBone3D = null
	for child in sim.get_children():
		var pb := child as PhysicalBone3D
		if pb == null:
			continue
		bodies[pb.get_bone_id()] = pb
		if pb.joint_type == PhysicalBone3D.JOINT_TYPE_NONE and anchor == null:
			anchor = pb
	if anchor == null or bodies.size() < 2:
		print("SPIKE %s FAIL no_anchor_or_bodies" % _variant.to_upper())
		quit(1)
		return
	var height := _model_height(model, skeleton, bodies)
	## The models save their simulator disabled (RagdollDriver enables it before it starts): so does the spike.
	sim.process_mode = Node.PROCESS_MODE_INHERIT
	if _variant == "f":
		## F: a death fall onto a floor 1 m below, every bone simulating. Shows whether the joints keep the body together.
		var floor_body := StaticBody3D.new()
		floor_body.collision_layer = 0xFFFFFFFF
		floor_body.collision_mask = 0xFFFFFFFF
		var floor_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(200.0, 1.0, 200.0)
		floor_shape.shape = box
		floor_body.add_child(floor_shape)
		floor_body.position = Vector3(0.0, -1.5, 0.0)
		root.add_child(floor_body)
		sim.physical_bones_start_simulation()
	elif _variant == "e" or _variant == "h":
		## E: D with the mirror taken out of every body_offset (det -1 -> +1). Tests whether the reflection breaks the joints.
		var flipped := 0
		for id: int in bodies:
			var bone := bodies[id] as PhysicalBone3D
			var off := bone.body_offset
			if off.basis.determinant() < 0.0:
				off.basis = off.basis.scaled(Vector3(1.0, 1.0, -1.0))
				bone.body_offset = off
				flipped += 1
		var dets := {}
		for id: int in bodies:
			var d := snappedf((bodies[id] as PhysicalBone3D).global_transform.basis.determinant(), 0.01)
			dets[d] = int(dets.get(d, 0)) + 1
		print("SPIKE %s detail mirrored_offsets=%d global_dets=%s" % [_variant.to_upper(), flipped, dets])
		sim.physical_bones_start_simulation()
	elif _variant == "i":
		## I: D, then every joint is rebuilt once all the bones simulate (joint_type off and on again).
		sim.physical_bones_start_simulation()
		await physics_frame
		for id: int in bodies:
			var bone := bodies[id] as PhysicalBone3D
			var kind := bone.joint_type
			if kind != PhysicalBone3D.JOINT_TYPE_NONE:
				bone.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
				bone.joint_type = kind
	elif _variant == "c" or _variant == "d" or _variant == "g":
		## Control: every bone simulating, no anchor and no motion (a free fall). Shows whether the joints hold at all.
		sim.physical_bones_start_simulation()
	elif _variant == "b":
		_add_hook(model, anchor)
		sim.physical_bones_start_simulation()
	else:
		var names: Array[StringName] = []
		for id: int in bodies:
			if bodies[id] != anchor:
				names.append(StringName((bodies[id] as PhysicalBone3D).bone_name))
		sim.physical_bones_start_simulation(names)
	await physics_frame
	var result := await _measure(holder, skeleton, bodies, anchor, height)
	var pass_all: bool = (result.anchor_err <= ANCHOR_ERR_MAX_M and result.stretch <= STRETCH_MAX
		and result.speed < SPEED_MAX_MPS and result.extent < EXTENT_MAX and not result.nan)
	print("SPIKE %s %s anchor_err_max=%.4f stretch_max=%.3f speed3s=%.3f extent=%.3f nan=%s" % [
		_variant.to_upper(), "PASS" if pass_all else "FAIL", result.anchor_err, result.stretch,
		result.speed, result.extent, str(result.nan).to_lower()])
	print("SPIKE %s detail anchor_err_end=%.4f height=%.3f bodies=%d" % [
		_variant.to_upper(), result.anchor_err_end, height, bodies.size()])
	quit(0)


func _add_hook(model: Node3D, anchor: PhysicalBone3D) -> void:
	var rest: Transform3D = model.global_transform.affine_inverse() * anchor.global_transform
	var hook := AnimatableBody3D.new()
	hook.name = "Hook"
	hook.collision_layer = 0
	hook.collision_mask = 0
	hook.sync_to_physics = true
	model.add_child(hook)
	hook.transform = rest
	var pin := Generic6DOFJoint3D.new()
	pin.name = "Pin"
	hook.add_child(pin)
	pin.transform = Transform3D.IDENTITY
	for axis in 3:
		_lock_axis(pin, axis)
	pin.node_a = pin.get_path_to(hook)
	pin.node_b = pin.get_path_to(anchor)


func _lock_axis(pin: Generic6DOFJoint3D, axis: int) -> void:
	var setters := [pin.set_flag_x, pin.set_flag_y, pin.set_flag_z]
	var params := [pin.set_param_x, pin.set_param_y, pin.set_param_z]
	setters[axis].call(Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
	setters[axis].call(Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
	params[axis].call(Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
	params[axis].call(Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
	params[axis].call(Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, 0.0)
	params[axis].call(Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, 0.0)


func _model_height(model: Node3D, skeleton: Skeleton3D, bodies: Dictionary) -> float:
	var aabb: AABB = model.get("bind_aabb")
	if aabb.size.y > 0.0:
		return aabb.size.y
	var lo := INF
	var hi := -INF
	for id: int in bodies:
		var y: float = (bodies[id] as PhysicalBone3D).global_position.y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return maxf(hi - lo, 0.01)


## Measures every physics tick: state first (what the last step produced), then the parent moves for the next step.
func _measure(holder: Node3D, skeleton: Skeleton3D, bodies: Dictionary, anchor: PhysicalBone3D, height: float) -> Dictionary:
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var rel_anchor: Vector3 = skeleton.global_transform.affine_inverse() * anchor.global_position
	var pairs := []
	for id: int in bodies:
		var parent_id := skeleton.get_bone_parent(id)
		while parent_id >= 0 and not bodies.has(parent_id):
			parent_id = skeleton.get_bone_parent(parent_id)
		if parent_id < 0:
			continue
		var rest_d := (bodies[id] as PhysicalBone3D).global_position.distance_to((bodies[parent_id] as PhysicalBone3D).global_position)
		if rest_d > 0.0001:
			pairs.append([bodies[id], bodies[parent_id], rest_d])
	var prev := {}
	for id: int in bodies:
		prev[id] = (bodies[id] as PhysicalBone3D).global_position
	var out := {"anchor_err": 0.0, "anchor_err_end": 0.0, "stretch": 0.0, "speed": 0.0, "extent": 0.0, "nan": false}
	var ticks := int((MOVE_S + MEASURE_AFTER_STOP_S) / dt)
	var rel_anchor_basis: Basis = (skeleton.global_transform.affine_inverse() * anchor.global_transform).basis
	for i in ticks:
		if _variant in ["d", "e", "g", "h", "i"]:
			## D: every bone simulates; the anchor gets the velocity that takes it to where the skeleton carries it this tick.
			var goal := skeleton.global_transform * rel_anchor
			if t_next_moves(i, dt):
				goal.x += SPEED_MPS * dt
			anchor.linear_velocity = (goal - anchor.global_position) / dt
			var want: Basis = skeleton.global_transform.basis * rel_anchor_basis
			var turn := (want * anchor.global_transform.basis.inverse()).get_rotation_quaternion()
			anchor.angular_velocity = turn.get_axis() * turn.get_angle() / dt if turn.get_angle() > 0.0001 else Vector3.ZERO
		await physics_frame
		var t := float(i) * dt
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for id: int in bodies:
			var p: Vector3 = (bodies[id] as PhysicalBone3D).global_position
			if not p.is_finite():
				out.nan = true
				continue
			lo = lo.min(p)
			hi = hi.max(p)
			if t >= MOVE_S + SPEED_WINDOW_FROM_S:
				out.speed = maxf(out.speed, p.distance_to(prev[id]) / dt)
			prev[id] = p
		if out.nan:
			break
		var err := anchor.global_position.distance_to(skeleton.global_transform * rel_anchor)
		out.anchor_err = maxf(out.anchor_err, err)
		out.anchor_err_end = err
		for pair in pairs:
			var d: float = (pair[0] as PhysicalBone3D).global_position.distance_to((pair[1] as PhysicalBone3D).global_position)
			out.stretch = maxf(out.stretch, d / float(pair[2]))
		out.extent = maxf(out.extent, (hi - lo).length() / height)
		if t < MOVE_S and _variant != "c" and _variant != "f":
			holder.position.x += SPEED_MPS * dt
	var loose := PackedStringArray()
	for pair in pairs:
		var d: float = (pair[0] as PhysicalBone3D).global_position.distance_to((pair[1] as PhysicalBone3D).global_position)
		if d / float(pair[2]) > 1.3:
			loose.append("%s->%s(%.1f,j%d)" % [(pair[0] as PhysicalBone3D).bone_name, (pair[1] as PhysicalBone3D).bone_name, d / float(pair[2]), (pair[0] as PhysicalBone3D).joint_type])
	print("SPIKE %s loose %d/%d: %s" % [_variant.to_upper(), loose.size(), pairs.size(), ", ".join(loose)])
	return out


func t_next_moves(i: int, dt: float) -> bool:
	return float(i) * dt < MOVE_S
