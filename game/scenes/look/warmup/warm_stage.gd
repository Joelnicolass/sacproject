class_name WarmStage
extends RefCounted

## What ShaderWarmup has on its stage right now: a batch of things drawn at the stage's place, as
## the match would draw them. A mesh, a material (on the probe mesh) and a stroke material (on the
## stroke probes) are RenderingServer instances for one frame; a bare shader gets a material made
## for that frame; a look scene is instanced under the stage twice, as it is and faded (a summoned,
## stealthy or playing-dead body draws in the transparent pass), and stays `draws` frames so its
## particles and skeleton move first.
## What it does not do: pick what to draw (WarmCollect), wait for frames (ShaderWarmup steps it) or
## keep anything once cleared.

var _stage: Node3D
var _probe: Mesh
var _draws := 1
var _faded := 0.0
var _rids: Array[RID] = []
## The materials made for the bare shaders of this frame (they live until it is drawn).
var _made: Array[ShaderMaterial] = []
## The look scenes on the stage, each [node, drawn frames it has left there] (a look may free itself
## meanwhile).
var _staged: Array[Array] = []
## What a ribbon the code draws looks like to the GPU: an ImmediateMesh with positions and UVs, as a
## strip and as triangles.
var _stroke_probes: Array[ImmediateMesh] = []


func _init(stage: Node3D, probe_mesh: Mesh, scene_draws: int, faded: float) -> void:
	_stage = stage
	_probe = probe_mesh
	_draws = maxi(1, scene_draws)
	_faded = faded


## Puts `batch` (meshes, materials, shaders, scenes) on the stage.
func draw(batch: Array) -> void:
	var scenario := _stage.get_world_3d().scenario
	var at := _stage.global_transform
	for item: Variant in batch:
		if item is Mesh:
			_rids.append(_instance((item as Mesh).get_rid(), scenario, at))
		elif item is Material and _probe != null:
			_dress_probe((item as Material).get_rid(), scenario, at)
		elif item is Shader and _probe != null:
			var made := ShaderMaterial.new()
			made.shader = item
			_made.append(made)
			_dress_probe(made.get_rid(), scenario, at)
		elif item is PackedScene:
			_stage_scene(item as PackedScene, 0.0)
			if _faded > 0.0:
				_stage_scene(item as PackedScene, _faded)


## Puts each of `materials` on every stroke probe (see WarmCollect.strokes).
func draw_strokes(materials: Array[Material]) -> void:
	if _stroke_probes.is_empty():
		_stroke_probes = [_stroke(Mesh.PRIMITIVE_TRIANGLE_STRIP), _stroke(Mesh.PRIMITIVE_TRIANGLES)]
	var scenario := _stage.get_world_3d().scenario
	for material in materials:
		for probe in _stroke_probes:
			var rid := _instance(probe.get_rid(), scenario, _stage.global_transform)
			RenderingServer.instance_geometry_set_material_override(rid, material.get_rid())
			_rids.append(rid)


## A frame was drawn: the meshes and materials go, and each look scene that has stayed its frames.
func step() -> void:
	_free_instances()
	var left: Array[Array] = []
	for entry in _staged:
		entry[1] -= 1
		if entry[1] > 0 and is_instance_valid(entry[0]):
			left.append(entry)
		elif is_instance_valid(entry[0]):
			(entry[0] as Node).queue_free()
	_staged = left


## True while a look scene is still on the stage.
func has_scenes() -> bool:
	return not _staged.is_empty()


## Everything off the stage now.
func clear() -> void:
	_free_instances()
	for entry in _staged:
		if is_instance_valid(entry[0]):
			(entry[0] as Node).queue_free()
	_staged.clear()


func _dress_probe(material: RID, scenario: RID, at: Transform3D) -> void:
	var rid := _instance(_probe.get_rid(), scenario, at)
	RenderingServer.instance_geometry_set_material_override(rid, material)
	_rids.append(rid)


## `packed` under the stage; with `transparency` > 0 every geometry in it drawn that faded.
func _stage_scene(packed: PackedScene, transparency: float) -> void:
	var node := packed.instantiate()
	_stage.add_child(node)
	if transparency > 0.0:
		for geometry in node.find_children("*", "GeometryInstance3D", true, false):
			(geometry as GeometryInstance3D).transparency = transparency
		if node is GeometryInstance3D:
			(node as GeometryInstance3D).transparency = transparency
	_staged.append([node, _draws])


func _free_instances() -> void:
	for rid in _rids:
		RenderingServer.free_rid(rid)
	_rids.clear()
	_made.clear()


## Six vertices with UVs in `primitive` (two triangles, or a strip of four).
static func _stroke(primitive: Mesh.PrimitiveType) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(primitive)
	for i in 6:
		mesh.surface_set_uv(Vector2(i % 2, i / 2))
		mesh.surface_add_vertex(Vector3(i % 2, i / 2, 0.0) * 0.5)
	mesh.surface_end()
	return mesh


static func _instance(base: RID, scenario: RID, at: Transform3D) -> RID:
	var rid := RenderingServer.instance_create2(base, scenario)
	RenderingServer.instance_set_transform(rid, at)
	return rid
