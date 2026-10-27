@tool
class_name ShaderWarmup
extends Node

## Behind the loading screen, draws once every mesh, material and look scene the match can show (WarmCollect finds them under the
## match scene, `ActiveMatch.warm_roots()` and the biome's look), a batch a frame at `stage` in front of the camera; then asks each
## WarmHook to draw its own and waits until the pipeline counters stay still for `settle_s`. So the first fireball does not stall.
## Says `progressed` (0..1) on the way and `finished` once. A headless process (the dedicated server) finishes as soon as the world
## is ready. What it does not do: load files (the flow), know the network (LoadReport tells it), or name what it warms.

signal progressed(ratio: float)
signal finished

## The match this warms (its scene is a root of the walk; the warm-up starts once it is ready).
@export var world: MatchWorld
## The land arrives here: the warm-up begins when its look is on the map (MatchBiome.applied).
@export var biome: MatchBiome
## Where it draws: a Marker3D a few meters in front of the match camera, hidden by the loading screen.
@export var stage: Marker3D
## A material with no mesh of its own is drawn on this one.
@export var probe_mesh: Mesh
## Things drawn per frame: more loads faster, fewer keeps each frame short.
@export_range(1, 512) var batch_size: int = 48
## The pipeline counters must stay still this long before it says `finished`.
@export_range(0.0, 5.0, 0.05, "suffix:s") var settle_s: float = 0.25
## Never waits longer than this (a land that never arrives, a slow GPU); keep it under the gate's load timeout.
@export_range(1.0, 120.0, 0.5, "suffix:s") var max_s: float = 20.0

var _over := false
var _rids: Array[RID] = []
var _nodes: Array[Node] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if DisplayServer.get_name() == "headless":
		world.ready.connect(_finish, CONNECT_ONE_SHOT)
		return
	biome.applied.connect(_on_biome_applied, CONNECT_ONE_SHOT)
	get_tree().create_timer(max_s, true).timeout.connect(_finish)


func _exit_tree() -> void:
	_clear()


func _on_biome_applied(god: GodType) -> void:
	var roots: Array = [god.look]
	if not world.scene_file_path.is_empty():
		roots.append(load(world.scene_file_path))
	roots.append_array(ActiveMatch.warm_roots())
	var items := WarmCollect.from_roots(roots).items()
	var steps := items.size() + 1
	for start in range(0, items.size(), batch_size):
		_draw(items.slice(start, start + batch_size))
		await RenderingServer.frame_post_draw
		_clear()
		if _over:
			return
		progressed.emit(float(mini(start + batch_size, items.size())) / steps)
	for hook in get_tree().get_nodes_in_group(WarmHook.GROUP):
		(hook as WarmHook).ask(stage)
	await _settled()
	_finish()


func _draw(batch: Array) -> void:
	var scenario := stage.get_world_3d().scenario
	var at := stage.global_transform
	for item: Variant in batch:
		if item is Mesh:
			_rids.append(_instance((item as Mesh).get_rid(), scenario, at))
		elif item is Material and probe_mesh != null:
			var rid := _instance(probe_mesh.get_rid(), scenario, at)
			RenderingServer.instance_geometry_set_material_override(rid, (item as Material).get_rid())
			_rids.append(rid)
		elif item is PackedScene:
			var node := (item as PackedScene).instantiate()
			stage.add_child(node)
			_nodes.append(node)


static func _instance(base: RID, scenario: RID, at: Transform3D) -> RID:
	var rid := RenderingServer.instance_create2(base, scenario)
	RenderingServer.instance_set_transform(rid, at)
	return rid


func _clear() -> void:
	for rid in _rids:
		RenderingServer.free_rid(rid)
	_rids.clear()
	for node in _nodes:
		if is_instance_valid(node):
			node.queue_free()
	_nodes.clear()


## Until the draw and specialization compilations stop growing for `settle_s` (or the time is up).
func _settled() -> void:
	var last := _compilations()
	var still_since := Time.get_ticks_msec()
	while not _over and Time.get_ticks_msec() - still_since < int(settle_s * 1000.0):
		await RenderingServer.frame_post_draw
		var now := _compilations()
		if now != last:
			last = now
			still_since = Time.get_ticks_msec()


static func _compilations() -> int:
	return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW) \
			+ RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION)


func _finish() -> void:
	if _over:
		return
	_over = true
	_clear()
	progressed.emit(1.0)
	finished.emit()


func _get_configuration_warnings() -> PackedStringArray:
	var missing := PackedStringArray()
	if world == null or biome == null or stage == null:
		missing.append("Faltan los sockets World, Biome o Stage: no precalienta nada.")
	if probe_mesh == null:
		missing.append("Sin Probe Mesh los materiales sueltos no se dibujan.")
	return missing
