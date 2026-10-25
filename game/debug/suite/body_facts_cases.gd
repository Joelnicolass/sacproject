extends RefCounted

## 055s (s1) case of rules_suite: the size and sockets a body scene saves (BodyFacts) are the ones BodyCatalog.info(model) gives today,
## so moving the readers to the scene changes nothing the rules see. For every CreatureType and WizardType:
##   - it points at a complete BodyFrame (with its `model_id`), with no synchronizer or spawner inside;
##   - height, radius, reach and flying height BodyFacts gives (decoded to the mm from the 32 bits the shapes and markers keep) are the
##     doubles BodyCatalog.info holds, bit for bit. `exact_double` counts the types whose four raw 32-bit numbers already were;
##   - the capsule is what BodyCollider used to compute (height >= 0.6, radius <= 0.45 of it), the ground one and the flying one;
##   - the Muzzle, Center and Top are the positions the code used to build from the height and the reach.
## Plus: BodyMount ignores the same scene twice, and BodyCollider writes the capsule of the scene a body wears (and only that).
## Prints BODY FACTS bodies=<n> equal=<n> differ=<n> and BODY FACTS doubles ... (the detail of the precision).

const CREATURES_DIR := "res://data/catalog/creatures/"
const WIZARDS_DIR := "res://data/catalog/wizards/"
const MIN_CAPSULE_M := 0.6
const RADIUS_PER_HEIGHT := 0.45
const HAND_FRACTION := 0.65
const MAX_LINES := 12

var _exact_double := 0
var _decoded_double := 0


func run(_host: Node) -> Dictionary:
	var bodies := 0
	var equal := 0
	var notes := PackedStringArray()
	for dir: String in [CREATURES_DIR, WIZARDS_DIR]:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".tres"):
				continue
			bodies += 1
			var problem := _check_type(dir + file, dir == WIZARDS_DIR)
			if problem.is_empty():
				equal += 1
			else:
				_note(notes, "%s: %s" % [file, problem])
	var mount_ok := _mount_is_idempotent()
	var collider_ok := _collider_writes_the_capsule()
	print("BODY FACTS bodies=%d equal=%d differ=%d" % [bodies, equal, bodies - equal])
	print("BODY FACTS doubles exact_double=%d decoded_mm_equals_double=%d of %d (the scene keeps 32 bits; see BodyFacts)" % [_exact_double, _decoded_double, bodies])
	for line in notes:
		print("BODY FACTS   " + line)
	print("BODY FACTS mount_idempotent=%s collider_writes_capsule=%s" % [mount_ok, collider_ok])
	return {"body_facts": {"ok": bodies > 0 and equal == bodies and mount_ok and collider_ok, "bodies": bodies, "equal": equal, "notes": notes}}


## "" when the type's body scene agrees with BodyCatalog.info(model), else what differs.
func _check_type(path: String, wizard: bool) -> String:
	var type := load(path) as Resource
	var scene := type.get("body") as PackedScene
	if scene == null:
		return "no body scene"
	var root := scene.instantiate()
	var frame := root as BodyFrame
	var model := frame.model_id if frame != null else ""
	var problem := ""
	if frame == null or not frame.is_complete():
		problem = "not a complete BodyFrame"
	elif not root.find_children("*", "MultiplayerSynchronizer", true, false).is_empty() \
			or not root.find_children("*", "MultiplayerSpawner", true, false).is_empty():
		problem = "the body scene carries a synchronizer or a spawner"
	root.free()
	if not problem.is_empty():
		return problem
	var facts := BodyFacts.of(scene)
	var info := BodyCatalog.info(model)
	var height := float(info.get("height", 0.0))
	var radius := float(info.get("radius", 0.0))
	var reach := float(info.get("reach", 0.0))
	var flying := float(info.get("height_flying", height))
	var sizes := {"height": [facts.height_m, height], "radius": [facts.radius_m, radius], "reach": [facts.reach_m, reach],
			"flying": [facts.flying_height_m, flying]}
	var exact := true
	var decoded := true
	for key: String in sizes:
		var pair: Array = sizes[key]
		if var_to_bytes(float(pair[0])) != var_to_bytes(float(pair[1])):
			return "%s: scene %s, BodyCatalog %s" % [key, str(pair[0]), str(pair[1])]
		exact = exact and PackedFloat32Array([pair[1]])[0] == float(pair[1])
		decoded = decoded and roundi(float(pair[0]) * 1000.0) / 1000.0 == float(pair[1])
	_exact_double += 1 if exact else 0
	_decoded_double += 1 if decoded else 0
	var capsule := _old_capsule(height, radius, wizard or model == "sacd", false)
	if facts.capsule_height_m != capsule.height or facts.capsule_radius_m != capsule.radius:
		return "capsule: scene %s x %s, BodyCollider rule %s x %s" % [str(facts.capsule_height_m), str(facts.capsule_radius_m), str(capsule.height), str(capsule.radius)]
	var air := _old_capsule(height, radius, wizard or model == "sacd", true, flying)
	if facts.flying_capsule_height_m != air.height:
		return "flying capsule: scene %s, BodyCollider rule %s" % [str(facts.flying_capsule_height_m), str(air.height)]
	var hand := Vector3.UP * height * HAND_FRACTION
	if facts.muzzle != Vector3(0.0, hand.y, Vector3(0.0, 0.0, reach).z):
		return "muzzle: scene %s, old rule (0, %s, %s)" % [str(facts.muzzle), str(hand.y), str(reach)]
	if facts.center != Vector3(0.0, height * 0.5, 0.0) or facts.top != Vector3(0.0, height, 0.0):
		return "center or top: scene %s %s, old rule from height %s" % [str(facts.center), str(facts.top), str(height)]
	return ""


## The CapsuleShape3D the three old writers built for a body: BodyCollider (units, the height as a double), wizard_body._fit_shape and
## doctor_body._fit_collision (the height as the shape stores it). `flying`: the capsule in the air (its height is the flying one).
func _old_capsule(height: float, radius: float, shape_height: bool, in_air: bool, flying_height := 0.0) -> CapsuleShape3D:
	var ground := maxf(height, MIN_CAPSULE_M)
	var shape := CapsuleShape3D.new()
	var tall := maxf(flying_height, MIN_CAPSULE_M) if in_air else ground
	shape.height = ground
	var limit := (shape.height if shape_height else ground) * RADIUS_PER_HEIGHT
	shape.height = tall
	shape.radius = minf(radius, limit)
	shape.height = tall
	return shape


func _mount_is_idempotent() -> bool:
	var scene := load("res://scenes/units/bodies/trogg.tscn") as PackedScene
	var other := load("res://scenes/units/bodies/dragon.tscn") as PackedScene
	if scene == null or other == null:
		return false
	var mount := BodyMount.new()
	var counter := [0]
	mount.worn.connect(func(_facts: BodyFacts) -> void: counter[0] += 1)
	mount.wear(scene)
	mount.wear(scene)
	mount.wear(null)
	var once: bool = counter[0] == 1 and mount.facts == BodyFacts.of(scene)
	mount.wear(other)
	var ok: bool = once and counter[0] == 2 and mount.facts == BodyFacts.of(other) and BodyFacts.of(scene) == BodyFacts.of(scene)
	mount.free()
	return ok


## BodyCollider copies the capsule of the worn scene into a shape of its own (the scene's shape is never written) and re-reads it.
func _collider_writes_the_capsule() -> bool:
	var scene := load("res://scenes/units/bodies/dragon.tscn") as PackedScene
	if scene == null:
		return false
	var mount := BodyMount.new()
	var collision := CollisionShape3D.new()
	var collider := BodyCollider.new()
	collider.mount = mount
	collider.collision = collision
	collider.refit()
	var untouched := collision.shape == null
	mount.wear(scene)
	collider.refit()
	var facts := BodyFacts.of(scene)
	var capsule := collision.shape as CapsuleShape3D
	var ok := untouched and capsule != null and capsule.height == facts.capsule_height_m and capsule.radius == facts.capsule_radius_m \
			and collision.position.y == facts.capsule_height_m * 0.5
	collider.free()
	collision.free()
	mount.free()
	return ok


func _note(notes: PackedStringArray, line: String) -> void:
	if notes.size() < MAX_LINES:
		notes.append(line)
