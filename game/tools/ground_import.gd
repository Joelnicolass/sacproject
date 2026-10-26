@tool
extends EditorScenePostImport

## Post-import of a map's ground.glb (RFC-063): the ONE way a free mesh becomes a ground. It reads every mesh of the glb, moves
## the map to x, z >= 0, cuts the walkable triangles longer than `max_edge_m`, cuts the map in chunks of `chunk_m`, writes
## ground.res (a MeshGroundData) next to the glb, only when it changed, and returns
##   Terrain / Chunks / Chunk_x_z ...   the drawn chunks (LOD included)
##           / Surface                  GroundSurface: the numbers, `meshes` = the chunks
##           / Collision                GroundCollision: the body to stand on
## The knobs are read from the glb's `.import` file (section [params], keys ground/<name>); a missing key takes its default.
## The helpers are in tools/ground/ and loaded by path: this script may run before the class cache exists.

const SOUP := preload("res://tools/ground/ground_soup.gd")
const SUBDIVIDE := preload("res://tools/ground/ground_subdivide.gd")
const CHUNKS := preload("res://tools/ground/ground_chunks.gd")
const SURFACE_SCRIPT := "res://scenes/map/terrain/ground_surface.gd"
const COLLISION_SCRIPT := "res://scenes/map/terrain/mesh/ground_collision.gd"
const DEFAULTS := {"max_edge_m": 10.0, "chunk_m": 100.0, "bucket_m": 10.0, "deform_cell_m": 10.0, "walkable_deg": 50.0, "lods": true}


func _post_import(scene: Node) -> Object:
	var started := Time.get_ticks_msec()
	var source := get_source_file()
	var options := read_options(source)
	var soup: Dictionary = SOUP.read(scene)
	if (soup["pos"] as PackedVector3Array).is_empty():
		push_error("ground import %s: the glb has no triangles." % source)
		return null
	var bounds: Rect2 = SOUP.move_to_origin(soup)
	if float(options["max_edge_m"]) > 0.0:
		soup = SUBDIVIDE.run(soup, float(options["max_edge_m"]), cos(deg_to_rad(float(options["walkable_deg"]))))
	var groups: Array = CHUNKS.group(soup, float(options["chunk_m"]))
	var data: Object = CHUNKS.build_data(soup, groups, bounds, options)
	if (data.get("bucket_tris") as PackedInt32Array).is_empty():
		push_error("ground import %s: no walkable triangle (is the mesh facing up, and is it flatter than %s degrees?)." % [source, options["walkable_deg"]])
		return null
	var saved := _write(data, source.get_base_dir().path_join("ground.res"))
	if saved == null:
		return null
	var root := _tree(CHUNKS.build_meshes(soup, groups, bool(options["lods"])), saved)
	scene.free()
	print("ground import %s: %d triangles in %d chunks, %.0f x %.0f m, %d ms" % [source, int(saved.call("triangle_count")), groups.size(),
			bounds.size.x, bounds.size.y, Time.get_ticks_msec() - started])
	return root


## The knobs of the glb: the defaults with whatever its `.import` file says under [params] as ground/<name>.
static func read_options(source: String) -> Dictionary:
	var options := DEFAULTS.duplicate()
	var file := ConfigFile.new()
	if file.load(source + ".import") == OK:
		for knob: String in options:
			options[knob] = file.get_value("params", "ground/" + knob, options[knob])
	return options


## ground.res is derived: it is rewritten only when its arrays differ, so a re-import without edits leaves git clean.
## Returns the saved resource as the file holds it (so the scene references the file), null if it could not be saved.
func _write(data: Object, out: String) -> Resource:
	var old: Resource = ResourceLoader.load(out, "", ResourceLoader.CACHE_MODE_IGNORE) if ResourceLoader.exists(out) else null
	var same := old != null
	for field in ["vertices", "indices", "bounds", "chunk_m", "bucket_m", "deform_cell_m", "walkable_deg", "chunks", "bucket_tris", "lowest_m"]:
		same = same and old.get(field) == data.get(field)
	if not same:
		var error := ResourceSaver.save(data as Resource, out)
		if error != OK:
			push_error("ground import: could not write %s (error %d)." % [out, error])
			return null
	return ResourceLoader.load(out, "", ResourceLoader.CACHE_MODE_REPLACE)


## The returned scene: the chunks, the surface that answers for them and the body that collides with them.
func _tree(chunk_meshes: Array, saved: Resource) -> Node3D:
	var root := Node3D.new()
	root.name = "Terrain"
	var holder := _child(root, Node3D.new(), "Chunks", root)
	var drawn: Array = []
	for entry: Dictionary in chunk_meshes:
		var chunk := MeshInstance3D.new()
		chunk.mesh = entry["mesh"]
		drawn.append(_child(holder, chunk, entry["name"], root))
	var surface := _child(root, Node.new(), "Surface", root)
	surface.set_script(load(SURFACE_SCRIPT))
	surface.set("mesh_data", saved)
	(surface.get("meshes") as Array).assign(drawn)
	var collision := _child(root, StaticBody3D.new(), "Collision", root)
	collision.set_script(load(COLLISION_SCRIPT))
	collision.set("surface", surface)
	return root


static func _child(parent: Node, node: Node, node_name: String, owner_node: Node) -> Node:
	node.name = node_name
	parent.add_child(node)
	node.owner = owner_node
	return node
