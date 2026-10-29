class_name PropBatch3D
extends Node3D

## Draws many props in a few draw calls. Every MeshInstance3D of every prop under `props` goes into
## a MultiMeshInstance3D per kind of part (mesh, material, shadow, layers, visibility range) and per
## square of `chunk_size`, so the camera culls by square; the part itself is hidden. The prop nodes
## stay as they are, for collision and the navmesh. A prop that leaves the tree is drawn out on the
## next frame (its square only). Call `refresh(prop)` after hiding or moving one, and
## `rebuild_all()` after adding props or changing what `mesh_of` answers. Draws nothing in the
## editor (there each prop shows itself, to move it with the gizmo) or with no display (a
## dedicated server, headless). A part with per-surface override materials is left as it is.

## Batch even with no display or in the editor (the kit's own tests; nothing draws there).
static var draw_anywhere := false

## The parents of the props (a PropScatter3D, or any node): each of their children is one prop.
@export var props: Array[Node] = []
## Side of a culling square.
@export_range(1.0, 10000.0, 1.0, "or_greater", "suffix:m") var chunk_size := 64.0
## Batch the props when this node is ready. Off: call `rebuild_all()` when the game wants it.
@export var build_on_ready := true

## Optional: `func(prop: Node3D, part: MeshInstance3D) -> Mesh`, the mesh to draw for that part
## (another look for the same prop, a level of detail...). Null answer = draw the part's own mesh.
var mesh_of := Callable()

## Chunk -> the parts drawn there; chunk -> its MultiMeshInstance3D nodes.
var _parts: Dictionary[Vector2i, Array] = {}
var _draws: Dictionary[Vector2i, Array] = {}
var _dirty: Dictionary[Vector2i, bool] = {}


func _ready() -> void:
	set_process(false)
	if build_on_ready:
		rebuild_all()


func _process(_delta: float) -> void:
	set_process(false)
	for chunk in _dirty:
		_build_chunk(chunk)
	_dirty.clear()


## True when this node draws (not in the editor, and with a display).
static func can_draw() -> bool:
	if draw_anywhere:
		return true
	return not Engine.is_editor_hint() and DisplayServer.get_name() != "headless"


## Frees every batch, shows the parts again, and batches every prop under `props` anew.
func rebuild_all() -> void:
	clear()
	if not can_draw():
		return
	for parent in props:
		if parent == null:
			continue
		for prop in parent.get_children():
			if prop is Node3D:
				_add(prop as Node3D)
	for chunk in _parts:
		_build_chunk(chunk)


## Draws `prop`'s square again (after hiding, showing or moving it inside its square).
func refresh(prop: Node3D) -> void:
	if not can_draw() or prop == null:
		return
	_mark(_chunk_of(prop.global_position))


## Frees every batch and shows the props' own meshes again.
func clear() -> void:
	# Freed nodes stay in these lists until a chunk is built again: check each one.
	for chunk in _draws:
		for draw: Variant in _draws[chunk]:
			if is_instance_valid(draw):
				(draw as Node).queue_free()
	for chunk in _parts:
		for part: Variant in _parts[chunk]:
			if is_instance_valid(part):
				(part as MeshInstance3D).visible = true
	_draws.clear()
	_parts.clear()
	_dirty.clear()


## How many MultiMeshInstance3D nodes draw the props now.
func batch_count() -> int:
	var total := 0
	for chunk in _draws:
		total += _draws[chunk].size()
	return total


## How many props' parts the batches draw now.
func instance_count() -> int:
	var total := 0
	for chunk in _draws:
		for draw: Variant in _draws[chunk]:
			if is_instance_valid(draw):
				total += (draw as MultiMeshInstance3D).multimesh.instance_count
	return total


func _add(prop: Node3D) -> void:
	var chunk := _chunk_of(prop.global_position)
	if not _parts.has(chunk):
		_parts[chunk] = []
	var found := prop.find_children("*", "MeshInstance3D", true, false)
	if prop is MeshInstance3D:
		found.append(prop)
	for part: MeshInstance3D in found:
		if _has_surface_overrides(part):
			continue
		_parts[chunk].append(part)
	var exiting := _on_prop_exiting.bind(chunk)
	if not prop.tree_exiting.is_connected(exiting):
		prop.tree_exiting.connect(exiting, CONNECT_ONE_SHOT)


func _on_prop_exiting(chunk: Vector2i) -> void:
	_mark(chunk)


func _mark(chunk: Vector2i) -> void:
	_dirty[chunk] = true
	set_process(true)


func _build_chunk(chunk: Vector2i) -> void:
	for draw: Variant in _draws.get(chunk, []):
		if is_instance_valid(draw):
			(draw as Node).queue_free()
	_draws.erase(chunk)
	var kept: Array = []
	var groups: Dictionary[Array, Array] = {}
	var to_local := global_transform.affine_inverse()
	for item: Variant in _parts.get(chunk, []):
		if not is_instance_valid(item):
			continue
		var part := item as MeshInstance3D
		if not part.is_inside_tree() or part.is_queued_for_deletion():
			continue
		kept.append(part)
		var prop := _prop_of(part)
		part.visible = true
		if prop == null or not prop.is_visible_in_tree():
			part.visible = false
			continue
		var mesh := part.mesh
		if mesh_of.is_valid():
			var answer: Variant = mesh_of.call(prop, part)
			if answer is Mesh:
				mesh = answer
		if mesh == null:
			continue
		var key := [
			mesh,
			part.material_override,
			part.cast_shadow,
			part.layers,
			part.visibility_range_begin,
			part.visibility_range_end,
			part.gi_mode
		]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(to_local * part.global_transform)
		part.visible = false
	_parts[chunk] = kept
	var draws: Array = []
	for key in groups:
		var transforms: Array = groups[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = key[0]
		multimesh.instance_count = transforms.size()
		for i in transforms.size():
			multimesh.set_instance_transform(i, transforms[i])
		var draw := MultiMeshInstance3D.new()
		draw.name = "Batch"
		draw.multimesh = multimesh
		draw.material_override = key[1]
		draw.cast_shadow = key[2]
		draw.layers = key[3]
		draw.visibility_range_begin = key[4]
		draw.visibility_range_end = key[5]
		draw.gi_mode = key[6]
		add_child(draw, true, Node.INTERNAL_MODE_BACK)
		draws.append(draw)
	_draws[chunk] = draws


## The prop a part belongs to: the child of one of `props` above it.
func _prop_of(part: Node) -> Node3D:
	var at := part
	while at != null:
		var parent := at.get_parent()
		if parent != null and props.has(parent):
			return at as Node3D
		at = parent
	return null


func _chunk_of(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / chunk_size), floori(at.z / chunk_size))


static func _has_surface_overrides(part: MeshInstance3D) -> bool:
	for i in part.get_surface_override_material_count():
		if part.get_surface_override_material(i) != null:
			return true
	return false
