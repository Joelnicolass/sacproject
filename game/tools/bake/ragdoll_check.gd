class_name RagdollCheck
extends RefCounted

## The round trip of a baked model: what the editor holds before saving against what the saved file gives back (capsule radius and
## height, transforms, body_offset, joint limits). Does NOT fix anything: it only says what differs.

const TOLERANCE := 1e-5
const LIMITS: PackedStringArray = ["joint_constraints/swing_span", "joint_constraints/twist_span"]


## One entry per physical bone under the model's simulator, keyed by bone node name.
static func snapshot(simulator: Node) -> Dictionary:
	var out := {}
	for body: PhysicalBone3D in simulator.find_children("*", "PhysicalBone3D", true, false):
		var entry := {"transform": body.transform, "offset": body.body_offset, "joint": body.joint_type, "limits": []}
		for key in LIMITS:
			# A body without a joint (the root) has no constraint properties: null.
			var limit: Variant = body.get(key)
			entry["limits"].append(float(limit) if limit != null else 0.0)
		var sizes: Array[Vector2] = []
		var places: Array[Transform3D] = []
		for shape: CollisionShape3D in body.find_children("*", "CollisionShape3D", false, false):
			var capsule := shape.shape as CapsuleShape3D
			sizes.append(Vector2(capsule.radius, capsule.height) if capsule != null else Vector2(-1.0, -1.0))
			places.append(shape.transform)
		entry["capsules"] = sizes
		entry["places"] = places
		out[body.name] = entry
	return out


## Reloads `path` and compares it with `before`. "" when equal, else the first difference.
static func compare(before: Dictionary, path: String) -> String:
	var packed := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if packed == null:
		return "cannot reload %s" % path
	var root := packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var found := root.find_children("Ragdoll", "PhysicalBoneSimulator3D", true, false)
	var error := "no Ragdoll after reload" if found.is_empty() else _diff(before, snapshot(found[0]))
	root.free()
	return error


static func _diff(a: Dictionary, b: Dictionary) -> String:
	if a.size() != b.size():
		return "bone count %d -> %d" % [a.size(), b.size()]
	for bone_name: String in a:
		if not b.has(bone_name):
			return "%s is gone" % bone_name
		var x: Dictionary = a[bone_name]
		var y: Dictionary = b[bone_name]
		if x["joint"] != y["joint"] or not _same(x["transform"], y["transform"]) or not _same(x["offset"], y["offset"]):
			return "%s: joint or transform changed" % bone_name
		for i in (x["limits"] as Array).size():
			if absf(x["limits"][i] - y["limits"][i]) > TOLERANCE:
				return "%s: joint limit %s changed" % [bone_name, LIMITS[i]]
		if (x["capsules"] as Array).size() != (y["capsules"] as Array).size():
			return "%s: capsule count changed" % bone_name
		for i in (x["capsules"] as Array).size():
			var p: Vector2 = x["capsules"][i]
			var q: Vector2 = y["capsules"][i]
			if absf(p.x - q.x) > TOLERANCE or absf(p.y - q.y) > TOLERANCE or not _same(x["places"][i], y["places"][i]):
				return "%s: capsule %s -> %s" % [bone_name, p, q]
	return ""


static func _same(a: Transform3D, b: Transform3D) -> bool:
	for i in 3:
		if (a.basis[i] - b.basis[i]).length() > TOLERANCE:
			return false
	return (a.origin - b.origin).length() <= TOLERANCE
