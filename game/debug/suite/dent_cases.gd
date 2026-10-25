extends RefCounted

## RFC-057 061k-4 cases of terrain_cases: the dents of Bombardment. The shape the meteorite's stamp makes (-1.2 m at the impact vertex,
## the half-circle profile out to 15 m, nothing beyond), then the real meteor scene on the map of High Noon: the impact vertex ends at
## -1.2 m, a second meteorite nearby adds to the first, the collision agrees with height_at, a meteorite lost in the sky leaves nothing,
## and the ground is put back at the end. It borrows the world of TerrainCases (`cases`): its bed and its checks.

const METEOR := preload("res://scenes/spells/drops/meteor.tscn")
## A vertex of the lattice on land (a meteorite that ends exactly on a vertex digs the full depth there).
const CENTER := Vector2(1260.0, 1270.0)
const DEPTH_M := 1.2
const RADIUS_M := 15.0

var _c


func _init(cases) -> void:
	_c = cases


func cases() -> Dictionary:
	return {"dent_rules": _rules, "dent_impact": _impact}


## The profile of the scene against the formula of the original, vertex by vertex.
func _rules() -> Dictionary:
	var checks := {}
	var meteor := METEOR.instantiate() as Node3D
	var stamp := meteor.get_node("Dent") as TerrainStamp
	var cylinder := (stamp.get_node("Reach") as CollisionShape3D).shape as CylinderShape3D
	checks["radius_15_depth_1_2"] = is_equal_approx(cylinder.radius, RADIUS_M) and is_equal_approx(cylinder.height, DEPTH_M)
	checks["manual_and_kept"] = stamp.manual and stamp.keep
	var rect := GroundField.vertex_rect(CENTER, cylinder.radius)
	var values := StampRules.values(stamp.profile, CENTER, cylinder.radius, cylinder.height, stamp.profile.duration_s() - 1e-4, rect)
	var worst := 0.0
	var centre_value := 0.0
	for row in rect.size.y:
		for column in rect.size.x:
			var spot := Vector2(rect.position + Vector2i(column, row)) * TerrainRules.CELL
			var wanted := _dent(spot.distance_to(CENTER))
			var got := values[row * rect.size.x + column]
			worst = maxf(worst, absf(got - wanted))
			if spot == CENTER:
				centre_value = got
	_c._note("dent profile worst error m / center", [worst, centre_value])
	checks["center_is_minus_1_2"] = absf(centre_value + DEPTH_M) < 0.01
	checks["profile_follows_the_formula"] = worst < 0.02
	meteor.free()
	return _c._verdict("dent_rules", checks)


## Two meteorites end on the map: -1.2 m under the first, and the second one 10 m away adds its own dent to the vertex between them.
func _impact() -> Dictionary:
	var checks := {}
	var shape: GroundSurface = _c._shape
	var ground := shape.field()
	var near := CENTER + Vector2(10.0, 0.0)
	var rect := Rect2i(Vector2i(CENTER / TerrainRules.CELL) - Vector2i(4, 4), Vector2i(9, 9))
	var before := ground.permanent.duplicate()
	var rev_before := ground.rev
	var base := shape.height_at(CENTER.x, CENTER.y)
	var base_near := shape.height_at(near.x, near.y)
	var first := _land(CENTER)
	checks["impact_vertex_minus_1_2"] = absf(shape.height_at(CENTER.x, CENTER.y) - base + DEPTH_M) < 0.01
	checks["10_m_away_is_half_circle"] = absf(shape.height_at(near.x, near.y) - base_near - _dent(10.0)) < 0.01
	checks["one_commit_no_live"] = ground.rev == rev_before + 1 and ground.live_count() == 0
	var second := _land(near)
	checks["dents_add_up_at_second"] = absf(shape.height_at(near.x, near.y) - base_near - (-DEPTH_M + _dent(10.0))) < 0.01
	checks["dents_add_up_at_first"] = absf(shape.height_at(CENTER.x, CENTER.y) - base - (-DEPTH_M + _dent(10.0))) < 0.01
	_c._collision.flush()
	await _c._frames(2)
	checks["ray_matches_height"] = absf(_c._ray(CENTER) - shape.height_at(CENTER.x, CENTER.y)) < 0.05
	var rev_now := ground.rev
	var lost := _meteor(CENTER + Vector2(40.0, 40.0))
	lost.free()
	checks["a_lost_meteor_leaves_nothing"] = ground.rev == rev_now and ground.live_count() == 0
	await _c._frames(2)
	for drop in [first, second]:
		if is_instance_valid(drop):
			(drop as Node).queue_free()
	var restore := PackedFloat32Array()
	restore.resize(rect.size.x * rect.size.y)
	for row in rect.size.y:
		for column in rect.size.x:
			var id := (rect.position.y + row) * GroundField.SIDE + rect.position.x + column
			restore[row * rect.size.x + column] = before[id] - ground.permanent[id]
	(_c._bed.get_node("Deformer") as TerrainDeformer).commit(rect, restore)
	await _c._frames(2)
	checks["ground_put_back"] = absf(shape.height_at(CENTER.x, CENTER.y) - base) < 1e-3
	return _c._verdict("dent_impact", checks)


## The dent of the original at `distance_m` from the impact: -sqrt(1 - d^2 / 15^2) * 1.2, nothing from 15 m on.
func _dent(distance_m: float) -> float:
	if distance_m >= RADIUS_M:
		return 0.0
	return -sqrt(1.0 - distance_m * distance_m / (RADIUS_M * RADIUS_M)) * DEPTH_M


## A meteor scene in the bed, standing at `spot` on the land, with only what the dent needs (no look, no blast).
func _meteor(spot: Vector2) -> ZoneDrop:
	var drop := METEOR.instantiate() as ZoneDrop
	for part in ["Spin", "Trail", "Blast"]:
		drop.get_node(part).free()
	drop.set_physics_process(false)
	drop.position = Vector3(spot.x, _c._shape.height_at(spot.x, spot.y), spot.y)
	_c._bed.add_child(drop)
	return drop


## The meteorite comes down at `spot` and its flight ends there.
func _land(spot: Vector2) -> ZoneDrop:
	var drop := _meteor(spot)
	drop.finish(null)
	return drop
