extends RefCounted

## RFC-054 054b (F381): CellRing against the golden recorded with GrassField's own ring code before the move
## (debug/look/cell_ring_golden.txt, poses in cell_ring_fixture.gd). Two replays:
## - cell_ring_golden: CellRing alone (update + field_center + fade_center), line by line;
## - cell_ring_grass_glue: a GrassField (not in the tree) driven through its `_update_cells`, reading the tier meta of its
##   nodes, so the layer's node bookkeeping matches the ring too.
## Plus cell_ring_changes: what `update` reports is exactly the difference between two states.

const FIXTURE := preload("res://debug/look/cell_ring_fixture.gd")
const GOLDEN := "res://debug/look/cell_ring_golden.txt"


func run() -> Dictionary:
	var golden := _golden()
	var results := {}
	results["cell_ring_golden"] = _compare(golden, _replay_ring())
	results["cell_ring_grass_glue"] = _compare(golden, _replay_grass())
	results["cell_ring_changes"] = _changes()
	return results


func _golden() -> PackedStringArray:
	if not FileAccess.file_exists(GOLDEN):
		return PackedStringArray()
	return FileAccess.get_file_as_string(GOLDEN).strip_edges().split("\n")


func _compare(golden: PackedStringArray, got: PackedStringArray) -> Dictionary:
	if golden.is_empty():
		return {"ok": false, "reason": "falta %s" % GOLDEN}
	if golden.size() != got.size():
		return {"ok": false, "reason": "%d lineas, el golden tiene %d" % [got.size(), golden.size()]}
	for i in golden.size():
		if golden[i] != got[i]:
			return {"ok": false, "line": i, "want": golden[i].left(160), "got": got[i].left(160)}
	return {"ok": true, "lines": got.size()}


func _ring(near_r: float) -> CellRing:
	var ring := CellRing.new(FIXTURE.CELL_M, FIXTURE.MAP_CELLS)
	ring.keep_margin_m = FIXTURE.KEEP_MARGIN_M
	ring.tier_hysteresis_m = FIXTURE.TIER_HYSTERESIS_M
	ring.tier_starts = FIXTURE.tier_starts(near_r)
	return ring


## `setup(near_r) -> Object` makes the state of a sequence; `step(state, radius, center, fade) -> Dictionary` (the tiers)
## runs every pose.
func _replay(step: Callable, setup: Callable) -> PackedStringArray:
	var lines := PackedStringArray()
	for s in FIXTURE.SEQUENCES.size():
		var near_r: float = FIXTURE.SEQUENCES[s].x
		var radius: float = FIXTURE.SEQUENCES[s].y
		var state: Object = setup.call(near_r)
		var center := Vector2.ZERO
		var has := false
		var index := 0
		for pose: Dictionary in FIXTURE.poses():
			var cam: Vector3 = pose["position"]
			var forward: Vector3 = pose["forward"]
			var target := CellRing.field_center(cam, forward, near_r, FIXTURE.GROUND_Y)
			if has:
				center = center.lerp(target, 1.0 - exp(-float(pose["delta"]) * FIXTURE.FOLLOW_RATE))
			else:
				center = target
				has = true
			var fade := CellRing.fade_center(cam, forward, FIXTURE.GROUND_Y)
			var tiers: Dictionary = step.call(state, radius, center, fade)
			lines.append(FIXTURE.line(s, index, center, fade, tiers))
			index += 1
		if state is Node:
			(state as Node).free()
	return lines


func _replay_ring() -> PackedStringArray:
	var step := func(ring: CellRing, radius: float, center: Vector2, fade: Vector2) -> Dictionary:
		ring.update(radius, fade, center)
		return ring.tiers()
	return _replay(step, _ring)


func _replay_grass() -> PackedStringArray:
	var image := Image.create(GrassField.HEIGHT_TEXELS, GrassField.HEIGHT_TEXELS, false, Image.FORMAT_RF)
	image.fill(Color(FIXTURE.GROUND_Y, 0.0, 0.0))
	var saved_image: Image = GrassField._height_image
	GrassField._height_image = image
	var step := func(field: GrassField, radius: float, center: Vector2, fade: Vector2) -> Dictionary:
		field._center = center
		field._update_cells(radius, fade)
		var tiers := {}
		for key in field._cells:
			tiers[key] = int(field._cells[key].get_meta(&"tier"))
		if tiers.size() != field._ring.size():
			tiers[Vector2i(-1, -1)] = -1  # the nodes and the ring disagree: the line cannot match
		return tiers
	var setup := func(near_r: float) -> GrassField:
		var field := GrassField.new()
		field._type = GrassType.new()
		field._tier_starts = FIXTURE.tier_starts(near_r)
		field._ring.tier_starts = field._tier_starts
		var meshes: Array[MultiMesh] = []
		for i in field._tier_starts.size():
			meshes.append(MultiMesh.new())
		field._tier_meshes = meshes
		return field
	var lines := _replay(step, setup)
	GrassField._height_image = saved_image
	return lines


## Every update's {added, removed, retiered} is the difference between the states before and after.
func _changes() -> Dictionary:
	var ring := _ring(15.0)
	var before := {}
	var updates := 0
	for pose: Dictionary in FIXTURE.poses():
		var cam: Vector3 = pose["position"]
		var forward: Vector3 = pose["forward"]
		var fade := CellRing.fade_center(cam, forward, FIXTURE.GROUND_Y)
		var changes := ring.update(38.25, fade, CellRing.field_center(cam, forward, 15.0, FIXTURE.GROUND_Y))
		var after := ring.tiers()
		var rebuilt := before.duplicate()
		for key in changes["removed"]:
			rebuilt.erase(key)
		for key in changes["added"]:
			rebuilt[key] = after[key]
		for key in changes["retiered"]:
			rebuilt[key] = after[key]
		if rebuilt != after:
			return {"ok": false, "update": updates}
		before = after
		updates += 1
	return {"ok": true, "updates": updates}
