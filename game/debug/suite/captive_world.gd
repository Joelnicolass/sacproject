extends RefCounted

## RFC-055 055a-5, debug only: the little world the captive_look_cases run in. A floor, a creature with the baked model of a Trogg mounted
## by hand (headless draws no model, like death_cases), a Sac Doctor, and the waits and the verdict every case shares.
## What it does not do: judge anything (the cases do).

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const DOCTOR_SCENE := preload("res://scenes/sacrifice/doctor.tscn")
const RULES := preload("res://data/match_rules.tres")
## The model the cases mount (a Trogg's).
const MODEL_TAG := "eorc"
const GUARD_FRAMES := 1200

var host: Node3D
var root: Node3D


## Adds the floor under `under` and keeps `under` as the host of the waits.
func setup(under: Node3D) -> void:
	host = under
	root = Node3D.new()
	root.name = "CaptiveLookCases"
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(800.0, 2.0, 800.0)
	shape.shape = box
	shape.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(shape)
	root.add_child(floor_body)
	host.add_child(root)


## A creature with the model mounted and bound, taken by a doctor and lifted: {unit, model, driver, doctor, taken}.
func hanging(rules: MatchRules) -> Dictionary:
	var body := make_unit(Vector3(0.0, 0.0, 6.0))
	var model := mount_model(body)
	var ragdoll := driver_of(body)
	ragdoll.bind_model(model)
	var carrier := make_doctor(rules)
	await wait_frames(20)
	var taken := Captive.of(body).take(carrier)
	await wait_until(func() -> bool: return body.global_position.y > 2.0)
	await wait_frames(30)
	return {"unit": body, "model": model, "driver": ragdoll, "doctor": carrier, "taken": taken}


## Frees a scenario. The bones stop first and the nodes leave through the queue: freeing bodies that still simulate crashes the engine.
func release(scenario: Dictionary) -> void:
	## The doctor goes in the same frame as what it carries: alive, it would still reach for the freed body.
	await dispose([scenario.doctor, scenario.unit], scenario.driver)


## Stops the ragdoll of `body`, queues it for deletion and waits two physics frames.
func dispose(bodies: Array, ragdoll: RagdollDriver) -> void:
	if ragdoll != null:
		ragdoll.set_pose(RagdollDriver.Pose.OFF)
	for body: Variant in bodies:
		## A body a case already killed (the doctor of dies_hanging) may be gone.
		if is_instance_valid(body):
			(body as Node).queue_free()
	await wait_frames(2)


## "pose=1 running=true mode=8": what a failing case prints next to the key.
func state(ragdoll: RagdollDriver, body: UnitBody) -> String:
	return "pose=%d running=%s mode=%d role='%s'" % [ragdoll.pose(), ragdoll.is_running(), body.mode, body.clips.captive_role]


func make_unit(at: Vector3) -> UnitBody:
	var body := UNIT_SCENE.instantiate() as UnitBody
	body.owner_slot = 2
	body.type = GameData.creature("ycro")
	body.model = body.type.model_id()
	body.rules = RULES
	body.idle_aggro = false
	body.target_groups = PackedStringArray()
	body.position = at
	root.add_child(body)
	(body.find_child("CaptiveLook", false, false) as CaptiveLook).hangs = true  # off by default in unit.tscn (plan 17)
	return body


func make_doctor(rules: MatchRules) -> DoctorBody:
	var carrier := DOCTOR_SCENE.instantiate() as DoctorBody
	carrier.owner_slot = 1
	carrier.rules = rules
	carrier.position = Vector3(0.0, 0.1, 0.0)
	root.add_child(carrier)
	return carrier


## The baked model of MODEL_TAG under the body's visual, in its idle pose and with its clips held (what the rig does at death).
func mount_model(body: UnitBody) -> BodyModel:
	var model := (load(BodyModel.scene_path(MODEL_TAG)) as PackedScene).instantiate() as BodyModel
	body.get_node("Tilt/Mesh").add_child(model)
	model.preview("idle")
	model.tree().advance(0.3)
	model.tree().callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	model.skeleton().force_update_all_bone_transforms()
	return model


func driver_of(body: UnitBody) -> RagdollDriver:
	return body.find_child("RagdollDriver", false, false) as RagdollDriver


func bone_points(model: BodyModel) -> PackedVector3Array:
	var skeleton := model.skeleton()
	var out := PackedVector3Array()
	for bone in skeleton.get_bone_count():
		out.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin)
	return out


func wait_frames(count: int) -> void:
	for _i in count:
		await host.get_tree().physics_frame


## Waits until `condition` holds or GUARD_FRAMES pass.
func wait_until(condition: Callable) -> void:
	for _i in GUARD_FRAMES:
		if condition.call():
			return
		await host.get_tree().physics_frame


## A check named `pending_*` is reported but does not fail the case (it waits for a cut that is not in yet, 055a-5j).
func verdict(checks: Dictionary, info := "") -> Dictionary:
	var ok := true
	for key in checks:
		if checks[key] is bool and not checks[key]:
			var pending := String(key).begins_with("pending_")
			ok = ok and pending
			print("captive_look_cases: %s %s %s" % ["pendiente" if pending else "falla", key, info])
	checks["ok"] = ok
	return checks
