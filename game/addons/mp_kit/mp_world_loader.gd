class_name MpWorldLoader
extends Node

## The one owner of a world load (MpFlow.goto_world): it reads the world scene and the extra files the game names on a thread,
## swaps the scene, then waits until the world says it is ready (MpFlow.report_world_*) or, when nobody waits for that, until the
## scene is in. It tells how far it got: 0..0.5 the files, 0.5..1 the world getting ready. What it read stays held until the
## scene goes elsewhere (no reload when the world spawns it). If the scene changes under it, the load is dropped (IDLE).
## Not: what to load (the flow and the game say), when the match starts (MpMatchGate), what a screen shows (it listens).

## The load moved on. `phase` FILES/WORLD = loading, READY = done, IDLE = dropped or over.
signal progressed(ratio: float, phase: Phase)
## The world is in and ready.
signal finished

enum Phase { IDLE, FILES, WORLD, READY }

## Seconds the world may take to say it is ready before the loader stops waiting (a world scene with nothing that reports).
@export var report_timeout_s := 30.0

var phase: Phase = Phase.IDLE

var _world_path := ""
var _world_scene: PackedScene
var _wait_report := false
var _requested: PackedStringArray = []
var _held: Array[Resource] = []
var _world: Node
var _world_since_ms := 0


func _init() -> void:
	## The start gate pauses the tree while a match waits: the load goes on.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	if not get_tree().scene_changed.is_connected(_on_scene_changed):
		get_tree().scene_changed.connect(_on_scene_changed)


## Loads `path` (on a thread), or `scene` when there is no path, as the new current scene, with `extra` read beside it.
## `wait_report` = stay in WORLD until report_loaded(). A load in course starts over.
func load_world(path: String, scene: PackedScene, extra: PackedStringArray, wait_report: bool) -> void:
	_drop(false)
	if path.is_empty() and scene == null:
		return
	_world_path = path
	_world_scene = scene
	_wait_report = wait_report
	var wanted := PackedStringArray([path]) if not path.is_empty() else PackedStringArray()
	wanted.append_array(extra)
	for file in wanted:
		if file.is_empty() or _requested.has(file):
			continue
		if ResourceLoader.load_threaded_request(file) == OK:
			_requested.append(file)
		elif file == path:
			push_error("MpWorldLoader: cannot load the world %s" % path)
			return
		else:
			push_warning("MpWorldLoader: cannot load %s; the world loads without it" % file)
	_set_phase(Phase.FILES, 0.0)
	_poll_files()


## The world says how far it got getting ready (0..1).
func report_progress(ratio: float) -> void:
	if phase == Phase.WORLD:
		progressed.emit(0.5 + 0.5 * clampf(ratio, 0.0, 1.0), phase)


## The world is ready. Only once per load.
func report_loaded() -> void:
	if phase != Phase.WORLD:
		return
	_set_phase(Phase.READY, 1.0)
	finished.emit()


func _process(_delta: float) -> void:
	if phase == Phase.FILES:
		_poll_files()
	elif phase == Phase.WORLD and _wait_report and Time.get_ticks_msec() - _world_since_ms > int(report_timeout_s * 1000.0):
		push_warning("MpWorldLoader: the world did not report itself loaded in %.0f s; going on" % report_timeout_s)
		report_loaded()


func _poll_files() -> void:
	var done := 0.0
	var all_in := true
	for file in _requested:
		var progress := []
		var status := ResourceLoader.load_threaded_get_status(file, progress)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			all_in = false
			done += float(progress[0]) if not progress.is_empty() else 0.0
		else:
			done += 1.0
	if not all_in:
		progressed.emit(0.5 * done / maxf(1.0, _requested.size()), phase)
		return
	_swap()


func _swap() -> void:
	for file in _requested:
		var res := ResourceLoader.load_threaded_get(file)
		if res != null:
			_held.append(res)
		if file == _world_path:
			_world_scene = res as PackedScene
	_requested.clear()
	if _world_scene == null:
		push_error("MpWorldLoader: the world %s is not a scene" % _world_path)
		_drop(true)
		return
	_set_phase(Phase.WORLD, 0.5)
	_world = null
	_world_since_ms = Time.get_ticks_msec()
	get_tree().change_scene_to_packed(_world_scene)


## The swap landed (adopt the world), or somebody else changed the scene (drop the load and what it held).
func _on_scene_changed() -> void:
	if phase == Phase.IDLE:
		return
	var current := get_tree().current_scene
	if phase == Phase.FILES or (_world != null and current != _world):
		_drop(true)
		return
	if _world == null:
		_world = current
		if phase == Phase.WORLD and not _wait_report:
			report_loaded()


func _drop(tell: bool) -> void:
	## A request still on its thread (a load dropped midway, rare) is waited for and let go.
	for file in _requested:
		ResourceLoader.load_threaded_get(file)
	_requested.clear()
	_held.clear()
	_world = null
	_world_scene = null
	_world_path = ""
	var was := phase
	phase = Phase.IDLE
	if tell and was != Phase.IDLE:
		progressed.emit(0.0, Phase.IDLE)


func _set_phase(next: Phase, ratio: float) -> void:
	phase = next
	progressed.emit(ratio, next)
