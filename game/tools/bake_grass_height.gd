extends SceneTree

## Bakes the map's land height to cache/look/height.exr for the grass layer (RFC-022e).
## RG float, 1024x1024 over the 2560 m map (2.5 m per texel): R = height, G = 1 where land lies
## under the texel centre (`Terrain.is_on_ground`), 0 over holes and the map rim. Hole texels take
## the height of the nearest land texel so a bilinear read near a hole edge does not dip to 0.
## "$GODOT" --headless --path game --script res://tools/bake_grass_height.gd

const TERRAIN := preload("res://scenes/world/terrain.gd")
const OUT := "res://cache/look/height.exr"
const SIZE := 1024
const MAP_M := 2560.0


func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var terrain := MeshInstance3D.new()
	terrain.set_script(TERRAIN)
	root.add_child(terrain)
	await process_frame
	if not terrain.call("has_ground_data"):
		push_error("Falta el terreno de High Noon (cache/high_noon_terrain.bin).")
		quit(1)
		return
	var texel := MAP_M / float(SIZE)
	var heights := PackedFloat32Array()
	heights.resize(SIZE * SIZE)
	var land := PackedByteArray()
	land.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			var found: float = terrain.call("ground_height", (x + 0.5) * texel, (y + 0.5) * texel)
			var at := y * SIZE + x
			if is_nan(found):
				heights[at] = NAN
				land[at] = 0
			else:
				heights[at] = found
				land[at] = 1
	_fill_holes(heights, land)
	var data := PackedByteArray()
	data.resize(SIZE * SIZE * 8)
	for i in SIZE * SIZE:
		data.encode_float(i * 8, heights[i])
		data.encode_float(i * 8 + 4, float(land[i]))
	var image := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGF, data)
	var path := ProjectSettings.globalize_path(OUT)
	var error := image.save_exr(path, false)
	if error != OK:
		push_error("No se pudo escribir %s (%d)" % [path, error])
		quit(1)
		return
	var lowest := INF
	var highest := -INF
	for i in SIZE * SIZE:
		lowest = minf(lowest, heights[i])
		highest = maxf(highest, heights[i])
	print("height.exr listo: %s alturas %.1f..%.1f en %d ms" % [path, lowest, highest, Time.get_ticks_msec() - started])
	quit(0)


## Breadth-first fill: each hole texel copies a land neighbour, ring by ring.
func _fill_holes(heights: PackedFloat32Array, land: PackedByteArray) -> void:
	var filled := land.duplicate()
	var changed := true
	var guard := 0
	while changed and guard < SIZE:
		changed = false
		guard += 1
		var next := filled.duplicate()
		for y in SIZE:
			for x in SIZE:
				var at := y * SIZE + x
				if filled[at] == 1:
					continue
				for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + step.x
					var ny: int = y + step.y
					if nx < 0 or ny < 0 or nx >= SIZE or ny >= SIZE:
						continue
					var other := ny * SIZE + nx
					if filled[other] == 1:
						heights[at] = heights[other]
						next[at] = 1
						changed = true
						break
		filled = next
	for i in SIZE * SIZE:
		if filled[i] == 0:
			heights[i] = 0.0
