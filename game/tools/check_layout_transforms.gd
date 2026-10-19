extends Node

## RFC-043 043a: proves that moving the rotation of the map's buildings and spawns from `facing_deg` (applied in _ready)
## into the node's own saved transform changed nothing in the world.
## "$GODOT" --headless --path game res://tools/check_layout_transforms.tscn -- --record   (old code only) writes the
##   baseline: per node, the transform the game used to end up with (position, and the yaw -deg_to_rad(facing_deg) of
##   _ready / MapPopulation), taken from the scene with the old script.
## "$GODOT" --headless --path game res://tools/check_layout_transforms.tscn              compares every building and
##   spawn of the saved scene (its stored transform, no _ready) against the baseline, at TOLERANCE.
## The baseline is kept in tools/layout_transforms_baseline.json so the check can be run again later.

const LAYOUT := "res://scenes/map/high_noon_layout.tscn"
const BASELINE := "res://tools/layout_transforms_baseline.json"
const GROUPS: PackedStringArray = ["Buildings", "NpcSpawns"]
const TOLERANCE := 1e-4


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var record := OS.get_cmdline_user_args().has("--record")
	var packed := load(LAYOUT) as PackedScene
	var root := packed.instantiate() as Node3D if packed else null
	if root == null:
		_end(false, "%s does not load" % LAYOUT)
		return
	if record:
		_end(_record(root), "record")
	else:
		_end(_compare(root), "compare")


func _row(transform: Transform3D, yaw: float) -> Array:
	var basis := transform.basis
	return [basis.x.x, basis.x.y, basis.x.z, basis.y.x, basis.y.y, basis.y.z, basis.z.x, basis.z.y, basis.z.z,
		transform.origin.x, transform.origin.y, transform.origin.z, yaw]


## Old code: the transform after `_ready` (buildings) and the yaw MapPopulation passed (spawns).
func _record(root: Node3D) -> bool:
	var data := {}
	for group_name in GROUPS:
		for node in root.get_node(group_name).get_children():
			var node3d := node as Node3D
			var facing := float(node.get("facing_deg"))
			var yaw := -deg_to_rad(facing)
			if group_name == "Buildings" and facing != 0.0:
				node3d.rotation.y = yaw
			if group_name == "NpcSpawns":
				node3d.rotation = Vector3.ZERO
				node3d.rotation.y = yaw
			data["%s/%s" % [group_name, node.name]] = _row(node3d.transform, yaw)
	var file := FileAccess.open(BASELINE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("check_layout_transforms: recorded %d nodes" % data.size())
	root.free()
	return true


## New code: the stored transform of each node, and for a spawn the yaw MapPopulation now reads.
func _compare(root: Node3D) -> bool:
	var data = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	if not data is Dictionary:
		print("check_layout_transforms: FAIL no baseline at %s" % BASELINE)
		return false
	var worst := 0.0
	var count := 0
	var failures := PackedStringArray()
	for group_name in GROUPS:
		for node in root.get_node(group_name).get_children():
			var key := "%s/%s" % [group_name, node.name]
			if not data.has(key):
				failures.append("%s: not in the baseline" % key)
				continue
			var want: Array = data[key]
			var node3d := node as Node3D
			var have := _row(node3d.transform, NAN)
			if group_name == "NpcSpawns":
				have[12] = float(node.call("yaw"))
			for k in 13:
				var delta := absf(float(want[k]) - float(have[k]))
				if group_name == "NpcSpawns" and k == 12:
					delta = _angle_distance(float(want[k]), float(have[k]))
				worst = maxf(worst, delta)
				if delta > TOLERANCE:
					failures.append("%s: component %d differs by %s" % [key, k, delta])
					break
			count += 1
	if count != data.size():
		failures.append("%d nodes in the scene, %d in the baseline" % [count, data.size()])
	root.free()
	for failure in failures:
		print("check_layout_transforms: FAIL %s" % failure)
	if failures.is_empty():
		print("check_layout_transforms: PASS %d nodes, worst difference %s (tolerance %s)" % [count, worst, TOLERANCE])
	return failures.is_empty()


func _angle_distance(a: float, b: float) -> float:
	return absf(wrapf(a - b, -PI, PI))


func _end(ok: bool, what: String) -> void:
	get_tree().quit(0 if ok else 1)
