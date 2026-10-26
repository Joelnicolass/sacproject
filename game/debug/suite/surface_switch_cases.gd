extends RefCounted

## RFC-067 case of rules_suite: the global relief switch (SurfaceReliefLayer). With one mesh per pilot material in the tree,
## switching off turns every pilot's `normal_enabled` off, a mesh that enters the tree afterwards is turned off too, and
## switching on gives back exactly what it took; the .tres on disk never changes (same md5 before and after).
## The pilots are the materials that have a flat copy in debug/look/surface_lab/flat/. Not: how the relief looks (surface_lab).

const FLAT_DIR := "res://debug/look/surface_lab/flat/"
const PRODUCT_DIR := "res://scenes/bodies/materials/"


func run(host: Node) -> Dictionary:
	var pilots: Array[BaseMaterial3D] = []
	var sums := {}
	for file in DirAccess.get_files_at(FLAT_DIR):
		if file.get_extension() != "tres":
			continue
		var material := load(PRODUCT_DIR + file) as BaseMaterial3D
		if material != null and material.normal_enabled and material.normal_texture != null:
			pilots.append(material)
			sums[PRODUCT_DIR + file] = FileAccess.get_md5(PRODUCT_DIR + file)
	var checks := {"has_pilots": not pilots.is_empty()}
	var stage := Node3D.new()
	host.add_child(stage)
	var layer := SurfaceReliefLayer.new()
	stage.add_child(layer)
	for material in pilots:
		stage.add_child(_mesh_with(material))
	layer.set_relief(false)
	checks["off_turns_pilots_off"] = pilots.all(func(m: BaseMaterial3D) -> bool: return not m.normal_enabled)
	var late := StandardMaterial3D.new()
	late.normal_enabled = true
	late.normal_texture = pilots[0].normal_texture if not pilots.is_empty() else null
	stage.add_child(_mesh_with(late))
	checks["late_mesh_turned_off"] = not late.normal_enabled
	layer.set_relief(true)
	checks["on_gives_back"] = pilots.all(func(m: BaseMaterial3D) -> bool: return m.normal_enabled) and late.normal_enabled
	layer.set_relief(false)
	stage.free()  # leaving the tree gives the maps back too
	checks["exit_gives_back"] = pilots.all(func(m: BaseMaterial3D) -> bool: return m.normal_enabled)
	checks["disk_unchanged"] = sums.keys().all(func(path: String) -> bool: return FileAccess.get_md5(path) == sums[path])
	var bad := PackedStringArray()
	for key: String in checks:
		if not bool(checks[key]):
			bad.append(key)
	print("SURFACE SWITCH pilots=%d %s" % [pilots.size(), "PASS" if bad.is_empty() else "FAIL " + ", ".join(bad)])
	return {"surface_switch": {"ok": bad.is_empty(), "failed": bad}}


func _mesh_with(material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.material_override = material
	return mesh
