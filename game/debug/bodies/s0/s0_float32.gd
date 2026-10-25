extends SceneTree
## 055s s0 (disposable), question 2: does a float32 survive saving and re-reading a .tscn, and is it today's double after the
## decode `roundi(v * 1000.0) / 1000.0` the plan uses (BodyFacts)?
## Cases: the real measures (height, radius, reach, the box of every body_sizes/*.tres), the plan's computed values (muzzle
## y = (UP * h * 0.65).y, center y = h * 0.5), and EVERY millimetre from 0.000 to 20.000 m. Carriers: Marker3D position
## (scene transform), BoxShape3D size and CapsuleShape3D radius/height (sub_resources). Also the fallback: doubles in
## `@export_storage` (a .tres) must come back bit for bit.
## Prints `S0 float32 ...` and `S0 VERDICT float32 ...`. Always ends in quit().

const DIR := "res://debug/bodies/s0/tmp/"
const SIZES := "res://data/catalog/body_sizes/"
const MAX_MM := 20000
const PER_NODE_SAMPLES := 3

var _bad_shown := 0


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("S0 VERDICT float32 TIMEOUT")
		quit(2))
	quit(_main())


func _main() -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var ig := FileAccess.open(DIR + ".gdignore", FileAccess.WRITE)
	if ig != null:
		ig.close()
	print("S0 float32 engine double-precision build=%s version=%s" % [OS.has_feature("double"), Engine.get_version_info().string])
	var real := _real_values()
	var ok := true
	ok = _markers(_mm_sweep(), "sweep") and ok
	ok = _markers(real, "real") and ok
	ok = _boxes(real) and ok
	ok = _capsules() and ok
	ok = _doubles(real) and ok
	print("S0 VERDICT float32 %s" % ("PASS the .tscn keeps float32 exact and the mm decode gives today's double" if ok else "FAIL see lines above; use the plan's question 11 fallback (@export_storage double) for the failing carrier"))
	return 0 if ok else 1


## [value] of every measure that is a double today.
func _real_values() -> Array[float]:
	var out: Array[float] = []
	var dir := DirAccess.open(SIZES)
	if dir == null:
		print("S0 float32 WARN cannot open %s" % SIZES)
		return out
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var bs := load(SIZES + f) as BodySize
		if bs == null:
			continue
		out.append(bs.height)
		out.append(bs.radius)
		out.append(bs.reach)
		for v in bs.box:
			out.append(v)
		out.append((Vector3.UP * bs.height * 0.65).y)
		out.append(bs.height * 0.5)
	print("S0 float32 real values read from body_sizes: %d" % out.size())
	return out


func _mm_sweep() -> Array[float]:
	var out: Array[float] = []
	for k in range(MAX_MM + 1):
		out.append(float(k) / 1000.0)
	return out


## Marker3D carrier: position written by the scene saver. Compares the re-read float32 with the in-memory one (bit exact)
## and the decode with today's double.
func _markers(values: Array[float], label: String) -> bool:
	var root_node := Node3D.new()
	var expect: Array[Vector3] = []
	var src: Array[Vector3] = []
	var i := 0
	while i < values.size():
		var d := Vector3(values[i], values[(i + 1) % values.size()], values[(i + 2) % values.size()])
		var m := Marker3D.new()
		m.name = "M%d" % src.size()
		root_node.add_child(m)
		m.owner = root_node
		m.position = d
		src.append(d)
		expect.append(m.position)
		i += PER_NODE_SAMPLES
	var path := DIR + "float32_%s.tscn" % label
	var back := _roundtrip(root_node, path)
	if back == null:
		return false
	var exact_ok := 0
	var exact_bad := 0
	var dec_ok := 0
	var dec_bad := 0
	var max_err := 0.0
	for n in range(src.size()):
		var got := (back.get_child(n) as Marker3D).position
		for axis in range(3):
			if got[axis] == expect[n][axis]:
				exact_ok += 1
			else:
				exact_bad += 1
				_show("marker %s #%d axis %d wrote %s read %s" % [label, n, axis, str(expect[n][axis]), str(got[axis])])
			var dec := roundi(got[axis] * 1000.0) / 1000.0
			if dec == src[n][axis]:
				dec_ok += 1
			else:
				dec_bad += 1
				_show("marker %s #%d axis %d today's double %s decoded %s" % [label, n, axis, str(src[n][axis]), str(dec)])
			max_err = maxf(max_err, absf(got[axis] - src[n][axis]))
	print("S0 float32 marker %s nodes=%d components=%d bitexact ok=%d bad=%d | decode==today's double ok=%d bad=%d | max |read - double|=%s" % [label, src.size(), exact_ok + exact_bad, exact_ok, exact_bad, dec_ok, dec_bad, str(max_err)])
	_text_sample(path, "M0")
	back.free()
	root_node.free()
	return exact_bad == 0 and dec_bad == 0


func _boxes(values: Array[float]) -> bool:
	var root_node := Node3D.new()
	var n := 0
	var src: Array[Vector3] = []
	var i := 0
	while i + 2 < values.size() and n < 4000:
		var d := Vector3(maxf(values[i], 0.001), maxf(values[i + 1], 0.001), maxf(values[i + 2], 0.001))
		var cs := CollisionShape3D.new()
		cs.name = "B%d" % n
		var bx := BoxShape3D.new()
		bx.size = d
		cs.shape = bx
		root_node.add_child(cs)
		cs.owner = root_node
		src.append(d)
		i += PER_NODE_SAMPLES
		n += 1
	var back := _roundtrip(root_node, DIR + "float32_box.tscn")
	if back == null:
		return false
	var bad := 0
	var dec_bad := 0
	for k in range(src.size()):
		var got := ((back.get_child(k) as CollisionShape3D).shape as BoxShape3D).size
		var want := ((root_node.get_child(k) as CollisionShape3D).shape as BoxShape3D).size
		for axis in range(3):
			if got[axis] != want[axis]:
				bad += 1
			if roundi(got[axis] * 1000.0) / 1000.0 != src[k][axis]:
				dec_bad += 1
	print("S0 float32 BoxShape3D.size shapes=%d bitexact bad=%d | decode!=today's double bad=%d" % [src.size(), bad, dec_bad])
	back.free()
	root_node.free()
	return bad == 0 and dec_bad == 0


func _capsules() -> bool:
	var root_node := Node3D.new()
	var src: Array[Vector2] = []
	var files := PackedStringArray()
	var dir := DirAccess.open(SIZES)
	if dir != null:
		files = dir.get_files()
	for f in files:
		if not f.ends_with(".tres"):
			continue
		var bs := load(SIZES + f) as BodySize
		if bs == null or bs.height <= 0.0 or bs.radius <= 0.0:
			continue
		var cs := CollisionShape3D.new()
		cs.name = "C%d" % src.size()
		var cap := CapsuleShape3D.new()
		cap.radius = bs.radius
		cap.height = maxf(bs.height, bs.radius * 2.0)
		cs.shape = cap
		root_node.add_child(cs)
		cs.owner = root_node
		src.append(Vector2(bs.radius, bs.height))
	var back := _roundtrip(root_node, DIR + "float32_capsule.tscn")
	if back == null:
		return false
	var bad := 0
	for k in range(src.size()):
		var got := (back.get_child(k) as CollisionShape3D).shape as CapsuleShape3D
		var want := (root_node.get_child(k) as CollisionShape3D).shape as CapsuleShape3D
		if got.radius != want.radius or got.height != want.height:
			bad += 1
			_show("capsule #%d wrote r=%s h=%s read r=%s h=%s" % [k, str(want.radius), str(want.height), str(got.radius), str(got.height)])
	print("S0 float32 CapsuleShape3D (radius, height) shapes=%d bitexact bad=%d" % [src.size(), bad])
	back.free()
	root_node.free()
	return bad == 0


## Fallback of question 11: doubles stored by `@export_storage` come back identical.
func _doubles(values: Array[float]) -> bool:
	var r := load("res://debug/bodies/s0/s0_dbl.gd").new() as Resource
	var probe: Array[float] = [1.915, 0.1 + 0.2, 1.0 / 3.0, 17.78, 0.001, 19.999]
	r.set("one", probe[1])
	var arr := PackedFloat64Array(values)
	arr.append_array(PackedFloat64Array(probe))
	r.set("many", arr)
	var path := DIR + "float64.tres"
	if ResourceSaver.save(r, path) != OK:
		print("S0 float32 ERROR saving %s" % path)
		return false
	var back := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if back == null:
		print("S0 float32 ERROR reading %s" % path)
		return false
	var got: PackedFloat64Array = back.get("many")
	var bad := 0
	for k in range(arr.size()):
		if k >= got.size() or got[k] != arr[k]:
			bad += 1
	var one_ok: bool = back.get("one") == probe[1]
	print("S0 float32 @export_storage doubles values=%d bad=%d single(0.1+0.2) exact=%s" % [arr.size(), bad, one_ok])
	return bad == 0 and one_ok


func _roundtrip(root_node: Node, path: String) -> Node:
	var ps := PackedScene.new()
	if ps.pack(root_node) != OK or ResourceSaver.save(ps, path) != OK:
		print("S0 float32 ERROR cannot save %s" % path)
		return null
	var back := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if back == null:
		print("S0 float32 ERROR cannot read %s" % path)
		return null
	return back.instantiate()


func _text_sample(path: String, node_name: String) -> void:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for k in range(lines.size()):
		if lines[k].begins_with("[node name=\"%s\"" % node_name) and k + 1 < lines.size():
			print("S0 float32 text of %s in %s: %s" % [node_name, path.get_file(), lines[k + 1]])
			return


func _show(msg: String) -> void:
	if _bad_shown < 12:
		_bad_shown += 1
		print("S0 float32 BAD %s" % msg)
