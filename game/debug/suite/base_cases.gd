extends RefCounted

## RFC-057 057c cases of terrain_cases: the bases of the map, on the island of debug/terrain/edit_bed.tscn (an altar at Start1 and
## a manafount). Bore's spiral run through the altar and through the manafount takes no vertex under either footprint, though the
## old rule (11 m from a part) would have let some go; a live stamp (an Erupt-like mound, every tick) and a kept one (a dent) over the
## altar leave the land under every footprint with pins_ground at 0 and the ring around it at most half of the free stamp. The stamps
## go through the Terrain API of the bed's own ground (two grounds live in the tree here, so the case asks it by hand, never
## Terrain.of). What that ground asks the tree (the parts and bases for a hole, the pins in its _ready, the bodies a stamp carries)
## must be the bed's own: each case checks first that no other base, building or body is there (`bed_alone`), and frees the bed at
## once when it ends, so no later case finds its altar or its ground. It borrows the checks of TerrainCases (`cases`).

const BED := preload("res://debug/terrain/edit_bed.tscn")
const SPIRAL_M := 50.0
const SPIRAL_STEP_M := 0.8
## Wide enough that its half (the free reference vertex, 50 m south) lies past the altar ring, and short of the manafount.
const REACH_M := 100.0
const MOUND_PEAK_M := 15.0
const MOUND_S := 1.0
const DENT_DEPTH_M := 1.2

var _c


func _init(cases) -> void:
	_c = cases


func cases() -> Dictionary:
	return {"base_hole": _hole, "base_pin": _pin}


## Bore's spiral through the altar and the manafount: holes under no footprint, and the base rule is what stops them.
func _hole() -> Dictionary:
	var checks := {}
	var bed := await _bed()
	var shape := bed.get_node("Terrain") as Terrain
	var footprints := _footprints(bed)
	checks["two_footprints"] = footprints.size() == 2
	checks["bed_alone"] = _alone(bed, footprints)
	var parts := HoleRules.parts_of(shape.get_tree())
	var old_rule_lets_go := false
	for footprint in footprints:
		var base := FootprintRules.vertices_under(footprint.area())
		for row in range(base.position.y, base.end.y):
			for column in range(base.position.x, base.end.x):
				old_rule_lets_go = old_rule_lets_go or HoleRules.can_remove(shape, Vector2i(column, row), parts)
	checks["old_rule_would_dig_a_base"] = old_rule_lets_go
	var cut := 0
	for footprint in footprints:
		var spiral := BoreSpiral.new(footprint.area().get_center(), SPIRAL_M, SPIRAL_STEP_M)
		while not spiral.arrived:
			cut += shape.cut_hole(spiral.advance()).size()
	var under := 0
	for footprint in footprints:
		var base := FootprintRules.vertices_under(footprint.area())
		for row in range(base.position.y, base.end.y):
			for column in range(base.position.x, base.end.x):
				under += 1 if shape.field().is_removed(TerrainGrid.id_of(Vector2i(column, row))) else 0
	_c._note("base hole cut / under a base", [cut, under])
	checks["the_spiral_dug"] = cut > 0
	checks["no_hole_under_a_base"] = under == 0
	_free(bed)
	await _c._frames(2)
	return _c._verdict("base_hole", checks)


## A live mound and a kept dent over the altar: 0 under every pinned footprint each tick, at most half the free stamp on the ring.
## The free stamp of a vertex is read off a vertex no base pins (the stamp is round), so the case does not depend on which tick
## Live drew.
func _pin() -> Dictionary:
	var checks := {}
	var bed := await _bed()
	var shape := bed.get_node("Terrain") as Terrain
	var footprints := _footprints(bed)
	checks["bed_alone"] = _alone(bed, footprints)
	var altar := footprints[0].area().get_center()
	var mound := _profile(MOUND_S)
	var worst := Vector3.ZERO
	for tick in int(MOUND_S * MatchClock.TICKS_PER_SECOND_F):
		shape.stamp(&"base_pin", mound, altar, REACH_M, MOUND_PEAK_M, float(tick) / MatchClock.TICKS_PER_SECOND_F)
		await _c._frames(1)
		var measured := _measure(shape, footprints, mound, altar)
		worst = Vector3(maxf(worst.x, measured.x), maxf(worst.y, measured.y), maxf(worst.z, measured.z))
	shape.unstamp(&"base_pin")
	await _c._frames(2)
	_c._note("base pin live worst under / ring excess / moved", [worst.x, worst.y, worst.z])
	checks["live_the_land_moved"] = worst.z > 1.0
	checks["live_base_level"] = worst.x <= 1e-4
	checks["live_ring_soft"] = worst.y <= 1e-3
	var dent := _profile(1.0)
	shape.keep_stamp(&"", dent, altar, REACH_M, -DENT_DEPTH_M)
	var kept := _measure(shape, footprints, dent, altar)
	_c._note("base pin kept worst under / ring excess / moved", [kept.x, kept.y, kept.z])
	checks["kept_the_land_moved"] = kept.z > 0.5
	checks["kept_base_level"] = kept.x <= 1e-4
	checks["kept_ring_soft"] = kept.y <= 1e-3
	_free(bed)
	await _c._frames(2)
	return _c._verdict("base_pin", checks)


## For a round stamp of `profile` and REACH_M at `center` (a lattice vertex): (worst |field| under a pinned footprint, worst excess
## of a ring vertex over half the free stamp there, largest |field| in the stamp). The free stamp comes from the vertex half the
## reach south of the center, which no base pins: amount = its value over the profile's share at that distance.
func _measure(shape: Terrain, footprints: Array[GroundFootprint], profile: StampProfile, center: Vector2) -> Vector3:
	var field := shape.field()
	var reference := center + Vector2(0.0, REACH_M * 0.5)
	var amount := field.at(TerrainGrid.vertex_id(reference.x, reference.y)) / profile.radial.sample(0.5)
	var rect := TerrainGrid.vertex_rect(center, REACH_M)
	var out := Vector3.ZERO
	for row in rect.size.y:
		for column in rect.size.x:
			var vertex := rect.position + Vector2i(column, row)
			var value := absf(field.at(TerrainGrid.id_of(vertex)))
			var distance := TerrainGrid.point_of(vertex).distance_to(center)
			var free := absf(amount * profile.radial.sample(distance / REACH_M)) if distance < REACH_M else 0.0
			out.z = maxf(out.z, value)
			for footprint in footprints:
				if not footprint.pins_ground:
					continue
				var base := FootprintRules.vertices_under(footprint.area())
				if base.has_point(vertex):
					out.x = maxf(out.x, value)
				elif base.grow(1).has_point(vertex):
					out.y = maxf(out.y, value - PinRules.RING_SHARE * free)
	return out


## A mound: (1 + cos(pi x)) / 2 across, growing in a line to its peak over `seconds`.
func _profile(seconds: float) -> StampProfile:
	var profile := StampProfile.new()
	profile.radial = Curve.new()
	profile.timeline = Curve.new()
	profile.timeline.max_domain = seconds
	for step in 11:
		var share := float(step) / 10.0
		profile.radial.add_point(Vector2(share, (1.0 + cos(PI * share)) * 0.5))
		profile.timeline.add_point(Vector2(share * seconds, share))
	return profile


## The island of edit_bed in the suite's world, without its look (a case draws nothing).
func _bed() -> Node3D:
	var bed := BED.instantiate() as MapRoot
	var look := bed.get_node("Look")
	bed.look = null
	look.free()
	_c._root.add_child(bed)
	await _c._frames(2)
	return bed


## Out of the tree and freed now (not at the end of the frame): its altar, manafount and ground leave every group at once.
func _free(bed: Node3D) -> void:
	bed.get_parent().remove_child(bed)
	bed.free()


## True when the bases, buildings and parts in the tree are all the bed's (HoleRules.parts_of/bases_of and PinRules.of_tree read
## the whole tree), and no body of the suite stands where the bed's ground may move (StampCarry would carry it).
func _alone(bed: Node3D, footprints: Array[GroundFootprint]) -> bool:
	var tree := bed.get_tree()
	for group in [GroundFootprint.GROUP, MapBuilding.GROUP, ManafountBody.GROUP, Altar.ANY_GROUP]:
		for node in tree.get_nodes_in_group(group):
			if not bed.is_ancestor_of(node):
				return false
	for group in [&"unit", &"wizard"]:
		for node in tree.get_nodes_in_group(group):
			var body := node as Node3D
			for footprint in footprints:
				var at := Vector2(body.global_position.x, body.global_position.z) if body != null else Vector2.INF
				if at.distance_to(footprint.area().get_center()) < REACH_M + SPIRAL_M:
					return false
	return true


## The footprints of the bed, the altar's first.
func _footprints(bed: Node) -> Array[GroundFootprint]:
	var found: Array[GroundFootprint] = []
	for path in ["MapProps/Starts/Start1/Altar/GroundFootprint", "MapProps/Founts/Fount1/GroundFootprint"]:
		var footprint := bed.get_node_or_null(path) as GroundFootprint
		if footprint != null:
			found.append(footprint)
	return found
