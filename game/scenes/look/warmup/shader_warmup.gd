@tool
class_name ShaderWarmup
extends Node

## Behind the loading screen, draws once every mesh, material, bare shader and look scene the match can show (WarmCollect finds them
## under the match scene, `world.warm_roots()` and the biome's look), a batch a frame at `stage` in front of the camera (a look scene
## twice: as it is and faded); then asks each WarmHook to draw its own and waits until the pipeline counters stay still for `settle_s`.
## So the first fireball does not stall. What it found stays held while the match lives: a summon does not read its look from disk.
## Says `progressed` (0..1) on the way and `finished` once. A headless process (the dedicated server) finishes as soon as the world
## is ready. The start gate pauses the tree meanwhile: `stage` always processes, so the particles and skeletons of a look move.
## What it does not do: load files (the flow; only the looks the walk finds), know the network (LoadReport tells it), or name what it warms.

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
## Drawn frames a look scene stays on the stage: its skeleton and its particles take a frame to be placed before they draw as in play.
@export_range(1, 8) var scene_draws: int = 2
## Each look scene is staged twice: as it is, and with this GeometryInstance3D.transparency (a body fades when it is summoned, goes
## stealthy or plays dead, and a faded material draws in the transparent pass, another pipeline). 0 = only as it is.
@export_range(0.0, 0.99, 0.01) var faded: float = 0.5
## The pipeline counters must stay still this long before it says `finished`.
@export_range(0.0, 5.0, 0.05, "suffix:s") var settle_s: float = 0.25
## Never waits longer than this (a land that never arrives, a slow GPU); keep it under the gate's load timeout.
@export_range(1.0, 120.0, 0.5, "suffix:s") var max_s: float = 20.0

var _over := false
## What is on the stage (made when the warm-up starts).
var _on_stage: WarmStage
## What the walk found, held while the match lives.
var _found: WarmCollect


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if DisplayServer.get_name() == "headless":
		world.ready.connect(_finish, CONNECT_ONE_SHOT)
		return
	biome.applied.connect(_on_biome_applied, CONNECT_ONE_SHOT)
	get_tree().create_timer(max_s, true).timeout.connect(_finish)


func _exit_tree() -> void:
	if _on_stage != null:
		_on_stage.clear()


func _on_biome_applied(god: GodType) -> void:
	## The gods and wizards first: the body looks they lead to are read on the loader's threads while the rest is walked.
	var roots: Array = world.warm_roots()
	if not world.scene_file_path.is_empty():
		roots.append(load(world.scene_file_path))
	roots.append(god.look)
	_found = WarmCollect.new()
	_found.add(roots)
	while not _found.read_looks():
		await get_tree().process_frame
		if _over:
			return
	var items := _found.items()
	var steps := items.size() + 1
	_on_stage = WarmStage.new(stage, probe_mesh, scene_draws, faded)
	_on_stage.draw_strokes(_found.strokes)
	for start in range(0, items.size(), batch_size):
		_on_stage.draw(items.slice(start, start + batch_size))
		await RenderingServer.frame_post_draw
		_on_stage.step()
		if _over:
			return
		progressed.emit(float(mini(start + batch_size, items.size())) / steps)
	while _on_stage.has_scenes():
		await RenderingServer.frame_post_draw
		_on_stage.step()
		if _over:
			return
	for hook in get_tree().get_nodes_in_group(WarmHook.GROUP):
		(hook as WarmHook).ask(stage)
	await _settled()
	_finish()


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
	if _on_stage != null:
		_on_stage.clear()
	progressed.emit(1.0)
	finished.emit()


func _get_configuration_warnings() -> PackedStringArray:
	var missing := PackedStringArray()
	if world == null or biome == null or stage == null:
		missing.append("Faltan los sockets World, Biome o Stage: no precalienta nada.")
	if probe_mesh == null:
		missing.append("Sin Probe Mesh los materiales sueltos no se dibujan.")
	return missing
