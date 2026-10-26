class_name TerrainShape
extends RefCounted

## The land a map's TerrainHeights makes, derived in one go and held in memory: its triangles (TerrainFaces) and their
## per-cell index (TerrainRules). In the editor it follows the heights and derives them again once they have been still
## for DELAY_S after a change (a reimport, a brush stroke), so a stroke never waits on it; then it tells `derived`.
## Not: the match state (GroundField), the answers (Terrain), the mesh (TerrainMesh).

## The triangles and the index were made again.
signal derived
## Editor: how long the heights must stay still before they are derived again.
const DELAY_S := 0.4

var faces := MapTerrainData.new()
var index := TerrainRules.Index.new()
var _heights: TerrainHeights
var _clock: Node
var _changed_ms := 0
var _waiting := false


## Derives `heights` now and, in the editor, again after each change of it. `clock` (the Terrain) gives the timers.
func follow(heights: TerrainHeights, clock: Node) -> void:
	if _heights != null and _heights.changed.is_connected(_on_changed):
		_heights.changed.disconnect(_on_changed)
	_heights = heights
	_clock = clock
	if heights != null and Engine.is_editor_hint():
		heights.changed.connect(_on_changed)
	derive()


## Makes the triangles and the index from the heights followed now (empty without valid heights).
func derive() -> void:
	var started := Time.get_ticks_usec()
	faces = TerrainFaces.build(_heights)
	index = TerrainRules.index(faces) if faces.is_valid() else TerrainRules.Index.new()
	if DebugLog.on(&"terrain_load"): print("terrain_load: %s faces + index %.0f ms (%d triangles)" % [str(_clock.name) if _clock else "?", (Time.get_ticks_usec() - started) / 1000.0, faces.indices.size() / 3])
	derived.emit()


## Editor: waits until the heights have been still for DELAY_S, then derives them once.
func _on_changed() -> void:
	_changed_ms = Time.get_ticks_msec()
	if _waiting or _clock == null or not _clock.is_inside_tree():
		return
	_waiting = true
	while is_instance_valid(_clock) and _clock.is_inside_tree() and Time.get_ticks_msec() - _changed_ms < DELAY_S * 1000.0:
		await _clock.get_tree().create_timer(DELAY_S).timeout
	_waiting = false
	if is_instance_valid(_clock):
		derive()
