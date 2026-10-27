extends RefCounted

## Cases of terrain_cases for the edges of the ground that moves: Erupt cast at the corner of the map and on the rim of its land plays
## its three stamps with no error, the land equals the stamps' own numbers and the collision agrees with height_at, and nothing is
## left; a cut Erupt takes its mound back on the next tick; a soul over a hole falls at 1 m/s and is gone `vanish_depth_m` under its
## last ground while one on the land stays on it; and the navmesh is baked again for a dent and a hole but not for a whole Erupt.
## It borrows the world of TerrainCases (`cases`): its bed, its makers of wizards and zones, its frames and its verdict.
## Ref: RFC-057 057d; sacengine Erupt cut (state.d:18386-18387), updateSoul (14912-14920).

const SOUL := preload("res://scenes/souls/soul.tscn")
const CENTER := Vector2(1260.0, 1270.0)
## Erupt: the burst comes 252 ticks after the zone is born and its last stamp is over at 313.
const BURST_TICKS := 252
const OVER_TICKS := 313
## A tick of the burst when every stamp of Erupt moves by more than the Live's step: the Live shows exactly what each one asks.
const CHECK_TICKS := 255
## The corner of the map (criterion: Erupt at 5, 5 m).
const CORNER := Vector2(5.0, 5.0)
const STAMPS: Array[String] = ["Mound", "Rebound", "Wave"]
## How far a short-lived soul falls before it is gone (the 50 m of the game would take 50 s).
const SHORT_DEPTH_M := 2.0

var _c


func _init(cases) -> void:
	_c = cases


func cases() -> Dictionary:
	return {"rim_stamp": _rim, "void_stamp": _void, "erupt_cancel": _cancel, "soul_hole": _soul_hole, "nav_trigger": _nav}


## Erupt at the corner of the map: its rect is cut by the edge of the lattice.
func _rim() -> Dictionary:
	return await _edge_erupt("rim_stamp", CORNER)


## Erupt on the rim of the land: the first vertex east of CENTER with no land on the cell past it.
func _void() -> Dictionary:
	var shape: Terrain = _c._shape
	var edge := Vector2.INF
	var x := CENTER.x
	while x < shape.bounds().end.x:
		if not shape.is_on_ground(x + 5.0, CENTER.y + 5.0):
			edge = Vector2(x, CENTER.y)
			break
		x += TerrainGrid.CELL_M
	if edge == Vector2.INF:
		return _c._verdict("void_stamp", {"found_the_rim": false})
	_c._note("void rim at", [edge])
	return await _edge_erupt("void_stamp", edge)


func _edge_erupt(label: String, spot: Vector2) -> Dictionary:
	var checks := {}
	var shape: Terrain = _c._shape
	var ground := shape.field()
	var rect := TerrainGrid.vertex_rect(spot, 100.0)
	var before := _shifts(rect)
	var keys_before := ground.live_count()
	var wizard: Node3D = _c._wizard(1, _c._far_wizard_spot(), "james", 6)
	var y := shape.height_at(spot.x, spot.y)
	var zone: GroundZone = _c._zone("Erupt", PackedVector3Array([Vector3(spot.x, 0.0 if is_nan(y) else y, spot.y)]), wizard, 0, BURST_TICKS)
	zone.release()
	var mound := zone.get_node("Mound") as TerrainStamp
	var ray := Vector2(-1.0, 0.0)
	while mound.ticks < CHECK_TICKS:
		if mound.ticks == 150 and ray.x < 0.0:
			ray = _ray_worst(spot)
		await _c._frames(1)
	var worst_ray := ray.x
	checks["three_keys"] = ground.live_count() - keys_before == 3
	var now := _shifts(rect)
	var wanted := _stamps_over(zone, rect)
	var worst := 0.0
	for row in rect.size.y:
		for column in rect.size.x:
			var k := row * rect.size.x + column
			if shape.index.land[TerrainGrid.id_of(rect.position + Vector2i(column, row))] == 1:
				worst = maxf(worst, absf(now[k] - before[k] - wanted[k]))
	checks["vertices_follow_the_stamps"] = worst <= 1e-4
	# The corner of High Noon may have no land within 45 m: there is nothing for the ray to meet. The rim of the land has.
	checks["ray_matches_height"] = worst_ray >= 0.0 and worst_ray <= 0.05 and (label != "void_stamp" or ray.y >= 20.0)
	while mound.ticks < OVER_TICKS + 2:
		await _c._frames(1)
	var after := _shifts(rect)
	var left := 0.0
	for k in after.size():
		left = maxf(left, absf(after[k] - before[k]))
	_c._note("%s: vertices worst / ray worst / ray points / left" % label, [worst, worst_ray, ray.y, left])
	checks["nothing_left"] = left < 0.01 and ground.live_count() == keys_before
	zone.queue_free()
	wizard.queue_free()
	await _c._frames(2)
	return _c._verdict(label, checks)


## A cast cut 0.5 s in: on the next ticks the ground is exactly what it was and no stamp plays, long before the zone is freed.
func _cancel() -> Dictionary:
	var checks := {}
	var ground: GroundField = (_c._shape as Terrain).field()
	var rect := TerrainGrid.vertex_rect(CENTER, 100.0)
	var before := _shifts(rect)
	var rev_before := ground.rev
	var keys_before := ground.live_count()
	var wizard: Node3D = _c._wizard(1, _c._far_wizard_spot(), "james", 6)
	var zone: GroundZone = _c._erupt(wizard)
	var mound := zone.get_node("Mound") as TerrainStamp
	while mound.ticks < 30:
		await _c._frames(1)
	checks["it_rose"] = ground.live_count() - keys_before == 1
	zone.cancel()
	await _c._frames(3)
	checks["zone_not_freed_yet"] = is_instance_valid(zone)
	var after := _shifts(rect)
	var worst := 0.0
	for k in after.size():
		worst = maxf(worst, absf(after[k] - before[k]))
	_c._note("erupt cut: left / live", [worst, ground.live_count() - keys_before])
	checks["ground_exactly_back"] = worst == 0.0
	checks["no_stamp_plays"] = ground.live_count() == keys_before
	checks["nothing_committed"] = ground.rev == rev_before
	if is_instance_valid(zone):
		zone.queue_free()
	wizard.queue_free()
	await _c._frames(2)
	return _c._verdict("erupt_cancel", checks)


## A soul on a vertex that Bore takes away falls 1 m a second and is gone `vanish_depth_m` under the ground it had; one on the land
## 30 m away stays on the land.
func _soul_hole() -> Dictionary:
	var checks := {}
	var shape: Terrain = _c._shape
	var spot := CENTER + Vector2(0.0, 30.0)
	var near := spot + Vector2(30.0, 0.0)
	var falling := _soul(spot)
	var staying := _soul(near)
	await _c._frames(10)
	var ground_y := shape.height_at(spot.x, spot.y)
	checks["on_the_land_first"] = absf(falling.global_position.y - ground_y) < 0.01
	checks["hole_cut"] = shape.cut_hole(spot).size() == 1
	_c._collision.flush()
	await _c._frames(2)
	var start_y := falling.global_position.y
	await _c._frames(60)
	var fell := start_y - falling.global_position.y
	_c._note("soul fell in 1 s", [fell])
	checks["falls_1_m_a_second"] = absf(fell - 1.0) <= 0.05
	var left_s := (SHORT_DEPTH_M - (ground_y - falling.global_position.y)) / falling.fall_speed
	await _c._frames(maxi(MatchClock.ticks_for(left_s - 0.2), 0))
	checks["still_there_before_the_depth"] = is_instance_valid(falling)
	await _c._frames(MatchClock.ticks_for(0.4))
	checks["gone_past_the_depth"] = not is_instance_valid(falling)
	var land := shape.height_at(near.x, near.y)
	checks["the_other_stays_on_the_land"] = is_instance_valid(staying) and absf(staying.global_position.y - land) < 0.01
	shape.fill_hole(spot)
	_c._collision.flush()
	for soul in [falling, staying]:
		if is_instance_valid(soul):
			(soul as Node).queue_free()
	await _c._frames(2)
	return _c._verdict("soul_hole", checks)


## A whole Erupt does not bake the navmesh again; a dent that stays bakes it once, and so does a hole.
func _nav() -> Dictionary:
	var checks := {}
	var shape: Terrain = _c._shape
	var service := NavService.new()
	service.name = "Nav"
	service.terrain = shape
	service.build_on_ready = false
	service.region = preload("res://debug/look/flora_test_maps.gd").nav_region_of(ActiveMatch.map())
	service.add_child(service.region)
	_c._collision.add_to_group(NavFingerprint.GROUP)
	_c._bed.add_child(service)
	service.build()
	await _c._frames(4)
	var wait := MatchClock.ticks_for(service.holes_rebake_s) + 10
	var wizard: Node3D = _c._wizard(1, _c._far_wizard_spot(), "james", 6)
	var zone: GroundZone = _c._erupt(wizard)
	var mound := zone.get_node("Mound") as TerrainStamp
	# The zone frees itself (and its Mound) soon after the Erupt is over: wait for the end, then a whole re-bake window.
	while is_instance_valid(mound) and mound.ticks < OVER_TICKS:
		await _c._frames(1)
	await _c._frames(wait)
	checks["erupt_bakes_nothing"] = service.rebakes == 0 and not service.is_rebaking()
	if is_instance_valid(zone):
		zone.queue_free()
	wizard.queue_free()
	_c._keep(shape, CENTER, 0.0, PackedFloat32Array([-1.2]))
	checks["dent_bakes_once"] = await _baked(service, 1)
	var hole := CENTER + Vector2(0.0, 40.0)
	checks["hole_cut"] = shape.cut_hole(hole).size() == 1
	checks["hole_bakes_once"] = await _baked(service, 2)
	_c._note("nav rebakes", [service.rebakes])
	shape.fill_hole(hole)
	_c._keep(shape, CENTER, 0.0, PackedFloat32Array([1.2]))
	service.queue_free()
	_c._collision.remove_from_group(NavFingerprint.GROUP)
	await _c._frames(2)
	return _c._verdict("nav_trigger", checks)


## Waits for the re-bake to be swapped in; true when the count is exactly `count` then.
func _baked(service: NavService, count: int) -> bool:
	## Real seconds, not frames: under --fixed-fps the frames outrun the worker that bakes.
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline and (service.rebakes < count or service.is_rebaking()):
		await _c._frames(1)
	return service.rebakes == count


## How far each vertex of `rect` (row by row) is from the file now.
func _shifts(rect: Rect2i) -> PackedFloat32Array:
	var ground := (_c._shape as Terrain).field()
	var out := PackedFloat32Array()
	for row in rect.size.y:
		for column in rect.size.x:
			out.append(ground.at(TerrainGrid.id_of(rect.position + Vector2i(column, row))))
	return out


## What the playing stamps of `zone` ask for over `rect` at their own second, added up.
func _stamps_over(zone: GroundZone, rect: Rect2i) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(rect.get_area())
	for stamp_name in STAMPS:
		var stamp := zone.get_node(stamp_name) as TerrainStamp
		var at := stamp.local_s()
		if at <= 0.0 or at >= stamp.profile.duration_s():
			continue
		var cylinder := stamp.reach.shape as CylinderShape3D
		var values := StampRules.shift(stamp.profile, stamp.center(), cylinder.radius, cylinder.height, at, rect, stamp.pattern)
		for k in values.size():
			out[k] += values[k]
	return out


## The worst gap between the collision's ray and height_at on up to 20 points of land within 45 m of `spot` (the rim included), and
## how many points it found.
func _ray_worst(spot: Vector2) -> Vector2:
	var shape: Terrain = _c._shape
	_c._collision.flush()
	var rng := MatchSeed.rng(["deform_edge_cases", "ray"])
	var spots := []
	var tries := 0
	while spots.size() < 20 and tries < 400:
		tries += 1
		var at := spot + Vector2(rng.randf_range(-45.0, 45.0), rng.randf_range(-45.0, 45.0))
		var height := shape.height_at(at.x, at.y)
		if not is_nan(height):
			spots.append([at, height])
	var worst := 0.0
	for pair: Array in spots:
		worst = maxf(worst, absf(_c._ray(pair[0]) - float(pair[1])))
	return Vector2(worst, spots.size())


## A free soul standing on the land at `spot`, with a short fall before it is gone.
func _soul(spot: Vector2) -> Soul:
	var soul := SOUL.instantiate() as Soul
	var y := (_c._shape as Terrain).height_at(spot.x, spot.y)
	soul.setup({"name": "EdgeSoul%d" % int(spot.x), "x": spot.x, "y": y, "z": spot.y, "emerging": false})
	soul.vanish_depth_m = SHORT_DEPTH_M
	_c._bed.add_child(soul)
	return soul
