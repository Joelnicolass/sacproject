extends RefCounted

## Cases of terrain_cases for the ground of a Quake: the real quake_wave.tscn on the map of High Noon sinks the land and sends its
## wave out the way the formula of the original says, at 0, 10, 25, 40 and 55 m on ticks 1, 5, 10, 20 and 29; the ground is back
## when it is over; and on the server only its two stamps play (the copy in quake_ring.tscn waits for a client). It borrows the
## world of TerrainCases (`cases`): its bed, its frames and its verdict.
## Ref: RFC-057 057a; sacengine Quake.displacement (state.d:5204-5222).

const WAVE := preload("res://scenes/units/abilities/quake_wave.tscn")
const RING := preload("res://scenes/fx/quake_ring.tscn")
## A vertex of the lattice on land, with land 60 m to its east (the row z = CENTER.y runs on cell edges: a point between two
## vertices is the straight line between them).
const CENTER := Vector2(1260.0, 1270.0)
const DISTANCES: Array[float] = [0.0, 10.0, 25.0, 40.0, 55.0]
const TICKS: Array[int] = [1, 5, 10, 20, 29]
## The Live redraws a stamp only when it moved by its `min_step_m` (0.1 m), so the sinking near its deepest lags a few cm.
const TOLERANCE_M := 0.05
const BACK_M := 0.01
## The 58 m reach of the wave around CENTER.
const RECT_M := 60.0

var _c


func _init(cases) -> void:
	_c = cases


func cases() -> Dictionary:
	return {"quake_ground": _ground}


func _ground() -> Dictionary:
	var checks := {}
	var shape: Terrain = _c._shape
	var ground := shape.field()
	var rect := TerrainGrid.vertex_rect(CENTER, RECT_M)
	var before := PackedFloat32Array()
	for row in rect.size.y:
		for column in rect.size.x:
			before.append(ground.at(TerrainGrid.id_of(rect.position + Vector2i(column, row))))
	var base := {}
	for d in DISTANCES:
		base[d] = shape.height_at(CENTER.x + d, CENTER.y)
	var keys_before := ground.live_count()
	var copy := RING.instantiate() as QuakeRing
	copy.get_node("Sound").free()
	copy.position = Vector3(CENTER.x, base[0.0], CENTER.y)
	_c._bed.add_child(copy)
	var wave := WAVE.instantiate() as QuakeWave
	wave.label = "quake_ground"
	wave.position = Vector3(CENTER.x, base[0.0], CENTER.y)
	_c._bed.add_child(wave)
	wave.begin()
	var rebound := wave.get_node("Ground/Rebound") as TerrainStamp
	checks["ring_copy_is_for_clients"] = (copy.get_node("Ground/Rebound") as TerrainStamp).on_clients_only \
		and (copy.get_node("Ground/Wave") as TerrainStamp).on_clients_only
	var worst := 0.0
	var seen := {}
	var most_keys := 0
	for _i in 40:
		await _c._frames(1)
		if not is_instance_valid(wave):
			break
		var tick := rebound.ticks
		most_keys = maxi(most_keys, ground.live_count() - keys_before)
		if tick in TICKS and not seen.has(tick):
			seen[tick] = true
			for d in DISTANCES:
				if is_nan(base[d]):
					continue
				var got: float = shape.height_at(CENTER.x + d, CENTER.y) - base[d]
				var wanted := _on_row(tick, d)
				worst = maxf(worst, absf(got - wanted))
				_c._note("quake t %d d %d got / wanted" % [tick, int(d)], [got, wanted])
	checks["every_tick_measured"] = seen.size() == TICKS.size()
	checks["follows_the_formula"] = worst <= TOLERANCE_M
	checks["two_keys_on_the_server"] = most_keys == 2
	await _c._frames(2)
	var left := 0.0
	for row in rect.size.y:
		for column in rect.size.x:
			var k := row * rect.size.x + column
			left = maxf(left, absf(ground.at(TerrainGrid.id_of(rect.position + Vector2i(column, row))) - before[k]))
	_c._note("quake worst / left after / most keys", [worst, left, most_keys])
	checks["wave_freed"] = not is_instance_valid(wave)
	checks["ground_back"] = left < BACK_M and ground.live_count() == keys_before
	if is_instance_valid(copy):
		copy.queue_free()
	await _c._frames(2)
	return _c._verdict("quake_ground", checks)


## What the ground shows at `d` m east of CENTER on frame `tick`: the formula at the lattice vertices, straight between two of them.
func _on_row(tick: int, d: float) -> float:
	var cell := TerrainGrid.CELL_M
	var low := floorf(d / cell) * cell
	var share := (d - low) / cell
	if share < 1e-6:
		return displacement(tick, low)
	return lerpf(displacement(tick, low), displacement(tick, low + cell), share)


## The Quake of the original at `dist` m from its center, `frame` ticks after it was born.
static func displacement(frame: int, dist: float) -> float:
	var wave_range := 50.0
	var fall_s := 0.15
	var wave_s := 0.5
	var time := float(frame) / 60.0
	var out := 0.0
	if time >= wave_s:
		return out
	var rebound := 0.5 * time / fall_s if time < fall_s else 0.5 + 0.5 * (time - fall_s) / (wave_s - fall_s)
	if dist < wave_range:
		out -= (1.0 + cos(PI * dist / wave_range)) * sin(PI * rebound) * 2.0
	var progress := time / wave_s
	var at := wave_range * progress
	var size := (0.15 + 0.65 * (1.0 - progress) * (1.0 - progress)) * wave_range
	var across := absf(dist - at) / size
	if across < 1.0:
		out += (1.0 + cos(PI * across)) * 1.5 * (1.0 - progress * progress) * minf(1.0, time / 0.05)
	return out
