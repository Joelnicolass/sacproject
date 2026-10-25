extends "res://debug/suite/zone_case_base.gd"

## RFC-057 061k-1 cases of rules_suite: the ground that moves. The arithmetic (a shifted corner, a taken-away vertex), the numbers
## GroundField keeps (live stamps leave no trace, a commit adds up, a snapshot copies), Erupt end to end on the map of
## High Noon (the mound at 4.2 s, the ground back at 5.2 s, the ray of the collision against height_at, the damage, the throw and
## the stun), a hole in the collision, and the plants planted again at the new height. No network here (terrain_late_join).

const BED := preload("res://debug/map/terrain_bed.tscn")
const Maps := preload("res://debug/look/flora_test_maps.gd")
const BORE_CASES := preload("res://debug/suite/bore_cases.gd")
const DENT_CASES := preload("res://debug/suite/dent_cases.gd")
## A vertex of the lattice of High Noon on land, with land 40 m to its east.
const CENTER := Vector2(1260.0, 1270.0)
const BURST_TICKS := 252
const OVER_TICKS := 313
## 061k-2 Volcano: it erupts 4.4444 s (267 ticks) after it starts and its mound is over 64.4444 s (3867 ticks) after it starts.
const ERUPT_TICKS := 267
const VOLCANO_OVER_TICKS := 3867
const VOLCANO_SHAPE := "res://assets/original/terrain/volcano_shape.png"

## Real seconds a case may take: past it the run fails and quits, so a stuck wait never holds the queue.
const CASE_CAP_S := 60.0

var _case_started := 0
var _bed: Node3D
var _shape: GroundSurface
var _collision: TerrainCollision
## The Bore cases (they borrow this world); kept here because their Callables do not keep them alive.
var _bore
var _dent


func run(host: Node3D) -> Dictionary:
	begin(host, "TerrainCases")
	var started := Time.get_ticks_usec()
	_bed = BED.instantiate() as Node3D
	_root.add_child(_bed)
	_note("collision chunks built ms", [snappedf((Time.get_ticks_usec() - started) / 1000.0, 0.1)])
	_shape = _bed.get_node("Shape") as GroundSurface
	_collision = _bed.get_node("Collision") as TerrainCollision
	await _frames(2)
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--case="):
			only = arg.trim_prefix("--case=")
	var cases := {
		"rules": _rules, "displacement": _displacement, "hole": _hole, "erupt_ground": _erupt_ground,
		"erupt_bodies": _erupt_bodies, "flora": _flora, "net": _net,
		"volcano_rules": _volcano_rules, "volcano_cut": _volcano_cut, "volcano_ground": _volcano_ground, "volcano_bodies": _volcano_bodies,
	}
	_bore = BORE_CASES.new(self)
	cases.merge(_bore.cases())
	_dent = DENT_CASES.new(self)
	cases.merge(_dent.cases())
	var out := {}
	for name: String in cases:
		if only.is_empty() or only == name:
			_case_started = Time.get_ticks_msec()
			out["terrain_" + name] = await (cases[name] as Callable).call()
	finish()
	return out


## Runs only the network case (debug/net/terrain_late_join.tscn).
func run_net(host: Node3D) -> Dictionary:
	begin(host, "TerrainNet")
	_case_started = Time.get_ticks_msec()
	var out := {"terrain_net": await _net()}
	finish()
	return out


## Server and clients in one process: the server's deformer commits, and each commit is handed to the client's deformer the way
## the RPC hands it (same arguments, same order); a client that joins late gets the snapshot, then only the newer commits count.
## The transport (ENet, the RPC itself) is the kit's and is not under test here.
func _net() -> Dictionary:
	var checks := {}
	var server := BED.instantiate() as Node3D
	var early := BED.instantiate() as Node3D
	var late := BED.instantiate() as Node3D
	for bed in [server, early, late]:
		_root.add_child(bed)
	await _frames(2)
	var host := server.get_node("Deformer") as TerrainDeformer
	var first := early.get_node("Deformer") as TerrainDeformer
	var second := late.get_node("Deformer") as TerrainDeformer
	var rect := GroundField.vertex_rect(CENTER, 35.0)
	var delta := PackedFloat32Array()
	delta.resize(rect.size.x * rect.size.y)
	for k in delta.size():
		delta[k] = 2.0 + sin(float(k))
	host.commit(rect, delta)
	first.rpc_commit(host.shape.field().rev, "", rect, delta)
	var hole := TerrainRules.vertex_id(CENTER.x, CENTER.y + 30.0)
	host.set_removed(hole, true)
	first.rpc_removed(host.shape.field().rev, hole, true)
	var truth := host.shape.field()
	checks["early_client_same"] = first.shape.field().checksum() == truth.checksum() and first.shape.field().rev == truth.rev
	first.rpc_commit(1, "", rect, delta)
	checks["old_commit_ignored"] = first.shape.field().checksum() == truth.checksum()
	second._on_snapshot({TerrainDeformer.SNAPSHOT_KEY: truth.to_snapshot()})
	checks["late_client_same"] = second.shape.field().checksum() == truth.checksum() and second.shape.field().rev == truth.rev
	second.rpc_commit(1, "", rect, delta)
	checks["late_ignores_commit_in_snapshot"] = second.shape.field().checksum() == truth.checksum()
	var more := PackedFloat32Array([0.5])
	host.commit(Rect2i(rect.position, Vector2i.ONE), more)
	for client in [first, second]:
		client.rpc_commit(truth.rev, "", Rect2i(rect.position, Vector2i.ONE), more)
	checks["both_follow_after"] = first.shape.field().checksum() == truth.checksum() and second.shape.field().checksum() == truth.checksum()
	checks["hole_arrived"] = second.shape.field().is_removed(hole) and not second.shape.is_on_ground(CENTER.x + 1.0, CENTER.y + 31.0)
	_note("net crc/rev", [truth.checksum(), truth.rev])
	for bed in [server, early, late]:
		bed.queue_free()
	return _verdict("terrain_net", checks)


## A corner that moved moves the height under it; a corner that was taken away leaves no land.
func _rules() -> Dictionary:
	var checks := {}
	var index := TerrainRules.index(_shape.data)
	var corners := index.corners
	var a := index.ground[0]
	var b := index.ground[1]
	var c := index.ground[2]
	var inside := (a + b + c) / 3.0
	var base := TerrainRules.height_in(inside.x, inside.z, index.ground, index.cells)
	var texels := PackedFloat32Array()
	texels.resize(GroundField.COUNT * 2)
	for k in 3:
		texels[corners[k] * 2] = 5.0
	var lifted := TerrainRules.height_in(inside.x, inside.z, index.ground, index.cells, texels, corners)
	checks["lifted_by_5"] = absf(lifted - base - 5.0) < 1e-3
	checks["no_shift_same_as_before"] = TerrainRules.height_in(inside.x, inside.z, index.ground, index.cells, PackedFloat32Array(), corners) == base
	texels[corners[0] * 2 + 1] = 1.0
	checks["hole_corner_no_land"] = is_nan(TerrainRules.height_in(inside.x, inside.z, index.ground, index.cells, texels, corners))
	checks["vertex_id"] = TerrainRules.vertex_id(1260.0, 1270.0) == 127 * 256 + 126
	checks["shape_without_shift_equals_rules"] = absf(_shape.height_at(inside.x, inside.z) - base) < 1e-6
	var spell := GameData.spell("tpre")
	var action := spell.action.instantiate() as ZoneAction if spell != null and spell.action != null else null
	checks["erupt_has_action"] = action != null and _spawner.zones.has(action.kind) and (_spawner.zones[action.kind] as PackedScene).can_instantiate()
	if action != null:
		action.tag = "tpre"
		checks["erupt_action_no_warnings"] = action._get_configuration_warnings().is_empty()
		action.free()
	return _verdict("terrain_rules", checks)


## Live stamps are summed again, never added: dropping one leaves exactly the ground it found. Commits add up; a snapshot copies.
func _displacement() -> Dictionary:
	var checks := {}
	var ground := GroundField.new()
	var rect := Rect2i(100, 100, 3, 3)
	var nine := PackedFloat32Array([1, 1, 1, 1, 1, 1, 1, 1, 1])
	ground.set_live("a", rect, nine)
	ground.set_live("b", Rect2i(101, 101, 1, 1), PackedFloat32Array([0.5]))
	checks["live_sums"] = ground.at(101 * 256 + 101) == 1.5 and ground.at(100 * 256 + 100) == 1.0
	ground.set_live("b", Rect2i(101, 101, 1, 1), PackedFloat32Array([0.25]))
	checks["live_replaces"] = ground.at(101 * 256 + 101) == 1.25
	ground.drop_live("b")
	ground.drop_live("a")
	checks["drop_leaves_nothing"] = ground.at(101 * 256 + 101) == 0.0 and ground.live_count() == 0
	ground.commit(rect, nine)
	ground.commit(rect, nine)
	checks["commit_adds"] = ground.at(100 * 256 + 100) == 2.0 and ground.rev == 2
	ground.set_live("c", rect, nine)
	ground.commit(rect, nine, "c")
	checks["commit_takes_live_in_one_step"] = ground.at(100 * 256 + 100) == 3.0 and ground.live_count() == 0
	checks["removed"] = ground.set_removed(5, true) and not ground.set_removed(5, true) and ground.removed_ids() == PackedInt32Array([5])
	var copy := GroundField.new()
	copy.apply_snapshot(ground.to_snapshot())
	checks["snapshot_copy"] = copy.checksum() == ground.checksum() and copy.rev == ground.rev and copy.at(100 * 256 + 100) == 3.0
	var rect_far := GroundField.vertex_rect(Vector2(1000.0, 1000.0), 25.0)
	checks["vertex_rect"] = rect_far == Rect2i(97, 97, 7, 7)
	return _verdict("terrain_displacement", checks)


## A lump on the ground reaches the collision: the ray finds it; a vertex taken away leaves a hole the ray passes through.
func _hole() -> Dictionary:
	var checks := {}
	var deformer := _bed.get_node("Deformer") as TerrainDeformer
	var spot := CENTER + Vector2(3.0, 63.0)
	var base := _shape.height_at(spot.x, spot.y)
	checks["on_land"] = not is_nan(base) and _collision.chunk_count() > 0
	var rect := GroundField.vertex_rect(spot, 20.0)
	var delta := PackedFloat32Array()
	delta.resize(rect.size.x * rect.size.y)
	delta.fill(4.0)
	deformer.commit(rect, delta)
	_collision.flush()
	await _frames(2)
	checks["height_lifted"] = absf(_shape.height_at(spot.x, spot.y) - base - 4.0) < 1e-3
	_note("lift base/expected/ray", [base, base + 4.0, _ray(spot)])
	checks["ray_sees_lift"] = absf(_ray(spot) - (base + 4.0)) < 0.05
	var id := TerrainRules.vertex_id(CENTER.x, CENTER.y + 60.0)
	spot = CENTER + Vector2(0.0, 60.0)
	deformer.set_removed(id, true)
	_collision.flush()
	await _frames(2)
	var around := true
	for corner in [Vector2(1.0, 1.0), Vector2(-1.0, 1.0), Vector2(1.0, -1.0), Vector2(-1.0, -1.0)]:
		around = around and not _shape.is_on_ground(spot.x + corner.x, spot.y + corner.y)
	checks["hole_no_ground"] = around and not _shape.is_on_ground(spot.x, spot.y)
	checks["ray_through_hole"] = is_nan(_ray(spot))
	deformer.set_removed(id, false)
	delta.fill(-4.0)
	deformer.commit(rect, delta)
	_collision.flush()
	await _frames(2)
	spot = CENTER + Vector2(3.0, 63.0)
	checks["back_to_base"] = absf(_shape.height_at(spot.x, spot.y) - base) < 1e-3 and absf(_ray(spot) - base) < 0.05
	checks["nothing_pending"] = _collision.pending_count() == 0
	return _verdict("terrain_collision_hole", checks)


## Erupt alone on the ground: 15 m at the center and 1.8 m at 40 m when the burst comes, the ray of the collision where
## height_at says, and nothing left a tick after 5.2 s.
func _erupt_ground() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, _far_wizard_spot(), "james", 6)
	var rev_before := _shape.field().rev
	var base_center := _shape.height_at(CENTER.x, CENTER.y)
	var base_40 := _shape.height_at(CENTER.x + 40.0, CENTER.y)
	var zone := _erupt(wizard)
	var mound := zone.get_node("Mound") as TerrainStamp
	var shifted := {}
	while mound.ticks < BURST_TICKS:
		if mound.ticks == 150 and not shifted.has("early"):
			shifted["early"] = true
			checks["ray_matches_height"] = await _ray_matches()
		await _frames(1)
	checks["center_15"] = absf(_shape.height_at(CENTER.x, CENTER.y) - base_center - 15.0) < 0.1
	checks["east_40_is_1_8"] = absf(_shape.height_at(CENTER.x + 40.0, CENTER.y) - base_40 - 1.8) < 0.1
	checks["only_the_mound_plays_at_4_2"] = _shape.field().live_count() == 1
	while mound.ticks < OVER_TICKS:
		await _frames(1)
	var worst := 0.0
	for id in GroundField.COUNT:
		worst = maxf(worst, absf(_shape.field().at(id)))
	checks["back_to_zero"] = worst < 0.01 and _shape.field().live_count() == 0
	checks["permanent_untouched"] = _shape.field().rev == rev_before
	zone.queue_free()
	wizard.queue_free()
	await _frames(2)
	return _verdict("terrain_erupt_ground", checks)


## The numbers of the burst on bodies at 5, 20, 45, 60 and 80 m, and one at 10 m that keeps standing on the rising ground.
func _erupt_bodies() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, _far_wizard_spot(), "james", 6)
	var bodies := {}
	for meters in [5.0, 10.0, 20.0, 45.0, 60.0, 80.0]:
		var at := Vector2(CENTER.x, CENTER.y + meters)
		var ground := _shape.height_at(at.x, at.y)
		bodies[meters] = _tough(Vector3(at.x, ground + 0.1, at.y), 3)
	await _frames(10)
	var zone := _erupt(wizard)
	var mound := zone.get_node("Mound") as TerrainStamp
	var lag := 0.0
	var before := (bodies[5.0].get_node("Health") as Health).current
	while mound.ticks < BURST_TICKS - 2:
		await _frames(1)
		if mound.ticks > 60 and mound.ticks % 30 == 0:
			var ten: Node3D = bodies[10.0]
			lag = maxf(lag, absf(ten.global_position.y - _shape.height_at(ten.global_position.x, ten.global_position.z)))
	_note("lag/ten y/ground", [lag, (bodies[10.0] as Node3D).global_position.y, _shape.height_at(CENTER.x, CENTER.y + 10.0)])
	checks["stands_on_rising_ground"] = lag < 0.5
	await _frames(4)
	checks["near_hurt"] = (bodies[5.0].get_node("Health") as Health).current < before
	checks["thrown_5"] = BodyNudge.tumbling_of(bodies[5.0]).is_on()
	checks["thrown_20"] = BodyNudge.tumbling_of(bodies[20.0]).is_on()
	checks["not_thrown_45"] = not BodyNudge.tumbling_of(bodies[45.0]).is_on()
	while mound.ticks < OVER_TICKS:
		await _frames(1)
	var stunned := func(meters: float) -> bool: return (bodies[meters].get_node("Afflictions/Stunned") as Stunned).cooldown_ticks() > 0
	checks["stunned_60"] = stunned.call(60.0)
	checks["not_stunned_45"] = not stunned.call(45.0)
	checks["not_stunned_80"] = not stunned.call(80.0)
	var far_hurt: bool = (bodies[20.0].get_node("Health") as Health).current < (bodies[20.0].get_node("Health") as Health).maximum
	checks["no_damage_past_15"] = not far_hurt
	zone.queue_free()
	for node: Node in bodies.values() + [wizard]:
		node.queue_free()
	await _frames(2)
	return _verdict("terrain_erupt_bodies", checks)


## The plants of the 32 m cells are planted again after the ground under them lifted 10 m: the sampler a job took before the
## lift keeps the old ground (copy-on-write), the one taken after sees the new one, and the cells the lift touches (and only
## them) are queued by the watch and built again by the planter. (Headless draws no mesh, so the buffers come from plan_cell.)
func _flora() -> Dictionary:
	var config := load("res://data/look/vegetation/original_plants.tres") as VegetationLayerConfig
	var flora := Maps.density_of("peaks")
	var land := Maps.land_of(MapCatalog.shared().find(&"peaks"))
	var checks := {}
	var groups := MeshPlanter.describe_groups(config, flora)
	var key := _fullest_cell(flora, groups)
	var quality := (load("res://data/look/quality_high.tres") as LookQuality).vegetation_for(config.id)
	var holder := Node3D.new()
	_root.add_child(holder)
	var planter := MeshPlanter.new(config, quality, flora, land.shape, holder)
	planter.threaded = false
	var spot := (Vector2(key) + Vector2(0.5, 0.5)) * MeshPlanter.CELL_M
	var eye := Vector3(spot.x, 30.0, spot.y)
	await _settle(planter, eye)
	var plain := MeshPlanter.plan_groups(groups)
	var old_ground := land.shape.sampler()
	var before := MeshPlanter.plan_cell(config, flora, plain, 1.0, key, old_ground, PackedVector4Array())
	var watch := FloraGroundWatch.new()
	watch.follow(land.shape)
	var rect := GroundField.vertex_rect(spot, 40.0)
	var delta := PackedFloat32Array()
	delta.resize(rect.size.x * rect.size.y)
	delta.fill(10.0)
	land.shape.field().commit(rect, delta)
	land.shape.notify_changed(rect)
	var after := MeshPlanter.plan_cell(config, flora, plain, 1.0, key, land.shape.sampler(), PackedVector4Array())
	checks["old_sampler_keeps_old_ground"] = MeshPlanter.plan_cell(config, flora, plain, 1.0, key, old_ground, PackedVector4Array()) == before
	checks["cell_has_plants"] = not before.is_empty() and before.size() == after.size()
	checks["plants_follow_the_lift"] = _lifted_by(before, after, 10.0)
	var area := Rect2(Vector2(rect.position) * TerrainRules.CELL, Vector2(rect.size) * TerrainRules.CELL)
	var touched := []
	for cell: Vector2i in planter._cells:
		if Rect2(Vector2(cell) * MeshPlanter.CELL_M, Vector2(MeshPlanter.CELL_M, MeshPlanter.CELL_M)).intersects(area):
			touched.append(cell)
	var built_before := planter.built_cells
	watch.update(1.0, 0.25, [planter], _host.get_tree())
	var queued := true
	for cell: Vector2i in touched:
		queued = queued and (planter._pending.has(cell) or planter._jobs.has(cell))
	checks["touched_cells_queued"] = not touched.is_empty() and queued and planter.pending_count() >= touched.size()
	await _settle(planter, eye)
	checks["touched_cells_built_again"] = planter.built_cells - built_before >= touched.size() and planter.pending_count() == 0
	checks["watch_quiet_after"] = planter.pending_count() == 0 and watch._moved.is_empty()
	_note("flora cells touched/rebuilt", [touched.size(), planter.built_cells - built_before])
	planter.clear()
	watch.follow(null)
	holder.free()
	land.free()
	return _verdict("terrain_flora", checks)


## Volcano on paper: its action and zone are wired, Pyro's book has it, the picture is the original's 33 x 33 grey, the pattern of the
## stamp (the picture times the peak, the flattening to the center's height) and the lava ball's shot are what the arithmetic says.
func _volcano_rules() -> Dictionary:
	var checks := {}
	var spell := GameData.spell("clov")
	var action := spell.action.instantiate() as ZoneAction if spell != null and spell.action != null else null
	checks["volcano_has_action"] = action != null and _spawner.zones.has(action.kind) and (_spawner.zones[action.kind] as PackedScene).can_instantiate()
	if action != null:
		action.tag = "clov"
		checks["volcano_action_no_warnings"] = action._get_configuration_warnings().is_empty()
		checks["volcano_action_on_lattice"] = action.snap_m == TerrainRules.CELL and action.arm_from_start
		action.free()
	var wizard := _wizard(1, _far_wizard_spot(), "pyro", 8)
	await _frames(2)
	checks["in_pyro_book"] = Caster.of(wizard).spellbook.index_of("clov") >= 0
	wizard.queue_free()
	var zone := (_spawner.zones["Volcano"] as PackedScene).instantiate() as GroundZone
	checks["zone_spell"] = zone.spell == spell and zone.hold_is_spell_duration
	var warned := []
	for child in zone.find_children("*", "", true, false):
		if child.has_method("_get_configuration_warnings") and not child._get_configuration_warnings().is_empty():
			warned.append(child.name)
	checks["zone_nodes_no_warnings"] = warned.is_empty()
	if not warned.is_empty():
		_note("nodes with warnings", warned)
	var shape := load(VOLCANO_SHAPE) as Texture2D
	var picture := shape.get_image()
	checks["picture_33"] = picture.get_size() == Vector2i(33, 33)
	checks["picture_center_255"] = picture.get_pixel(16, 16).r8 == 255 and picture.get_pixel(0, 0).r8 == 0
	var mound := zone.get_node("Mound") as TerrainStamp
	var reach := (mound.reach.shape as CylinderShape3D)
	var rect := GroundField.vertex_rect(CENTER, reach.radius)
	checks["mound_rect_33"] = rect.size == Vector2i(33, 33)
	var flat := PackedFloat32Array()
	flat.resize(33 * 33)
	flat.fill(100.0)
	var full := StampRules.pattern(mound.profile, CENTER, reach.radius, reach.height, rect, flat, 100.0)
	checks["pattern_center_is_the_peak"] = absf(full[16 * 33 + 16] - 0.2 * 255.0) < 1e-3
	var step := 17 * 33 + 20
	checks["pattern_is_picture_times_0_2"] = absf(full[step] - 0.2 * float(picture.get_pixel(20, 17).r8)) < 1e-3
	flat.fill(90.0)
	var east_100 := 16 * 33 + 26
	var share := 1.0 - (100.0 - 80.0) / (164.0 - 80.0)
	var dug := StampRules.pattern(mound.profile, CENTER, reach.radius, reach.height, rect, flat, 100.0)
	checks["pattern_flattens_100m"] = absf(dug[east_100] - (10.0 * share + 0.2 * float(picture.get_pixel(26, 16).r8))) < 0.01
	checks["pattern_flat_inside_80m"] = absf(dug[16 * 33 + 24] - (10.0 + 0.2 * float(picture.get_pixel(24, 16).r8))) < 1e-3
	var heat := zone.get_node("Burn") as ZoneHeat
	checks["heat_falls_20_to_50"] = heat.strength_at(20.0) == 1.0 and absf(heat.strength_at(35.0) - 0.5) < 1e-5 and heat.strength_at(50.0) == 0.0
	var shot := ZoneRules.shot_velocity(Vector3.ZERO, Vector3(100.0, 0.0, 0.0), 30.0, 30.0)
	checks["shot_leans_up_for_gravity"] = shot.is_equal_approx(Vector3(30.0, 50.0, 0.0))
	checks["lava_ball_registered"] = _spawner.projectiles.has("LavaBall") and (_spawner.projectiles["LavaBall"] as PackedScene).can_instantiate()
	zone.free()
	return _verdict("terrain_volcano_rules", checks)


## A cast that is cut: the mound goes at once and the ground is exactly what it was (nothing kept, no commit).
func _volcano_cut() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, _far_wizard_spot(), "pyro", 8)
	var ground := _shape.field()
	var rev_before := ground.rev
	var zone := _volcano(wizard)
	var mound := zone.get_node("Mound") as TerrainStamp
	while mound.ticks < 150:
		await _frames(1)
	var raised := 0.0
	for id in GroundField.COUNT:
		raised = maxf(raised, absf(ground.at(id)))
	checks["it_rose"] = raised > 20.0 and ground.live_count() == 1
	zone.cancel()
	await _frames(3)
	var worst := 0.0
	var kept := 0.0
	for id in GroundField.COUNT:
		worst = maxf(worst, absf(ground.at(id)))
		kept = maxf(kept, absf(ground.permanent[id]))
	_note("cut: raised/after/kept/live", [raised, worst, kept, ground.live_count()])
	checks["grid_exactly_zero"] = worst == 0.0 and kept == 0.0
	checks["nothing_committed"] = ground.rev == rev_before and ground.live_count() == 0
	zone.queue_free()
	wizard.queue_free()
	await _frames(2)
	return _verdict("terrain_volcano_cut", checks)


## The whole spell on the ground: the mound rises with the cast (0.75 of 51 m at 3.33 s), the crater opens at 4.44 s, and when it is over
## (64.44 s) the ground keeps a quarter of the mound plus the crater, over the vertices of the picture and the flattening, as the formulas
## of the original give them; nothing outside the 33 x 33 changes, two commits were made and no stamp is left playing.
func _volcano_ground() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, _far_wizard_spot(), "pyro", 8)
	var rect := GroundField.vertex_rect(CENTER, 160.0)
	var before := StampRules.ground_under(_shape, rect)
	var rev_before := _shape.field().rev
	var target := before[16 * 33 + 16]
	var picture := (load(VOLCANO_SHAPE) as Texture2D).get_image()
	var zone := _volcano(wizard)
	var mound := zone.get_node("Mound") as TerrainStamp
	var crater := zone.get_node("Crater") as TerrainStamp
	while mound.ticks < 200:
		await _frames(1)
		if mound.ticks == 100:
			checks["ray_matches_height"] = await _ray_matches()
	var rise := _shape.height_at(CENTER.x, CENTER.y) - target
	_note("mound at 3.33 s (expected 38.25)", [rise])
	checks["center_rises_with_the_cast"] = absf(rise - 51.0 * 200.0 / 266.6667) < 0.3
	while mound.ticks < 285:
		await _frames(1)
	var opened := _shape.height_at(CENTER.x, CENTER.y) - target
	_note("center after the crater (expected 40.86)", [opened])
	checks["crater_opens_at_the_eruption"] = absf(opened - (51.0 * (1.0 - 0.0125 * (285.0 / 60.0 - 4.4444)) - 10.0)) < 0.3 and crater.ticks > ERUPT_TICKS
	checks["two_stamps_playing_then_one"] = _shape.field().live_count() == 1 and _shape.field().rev == rev_before + 1
	for stamp in [mound, crater]:
		(stamp as TerrainStamp).ticks = VOLCANO_OVER_TICKS - 3
		(stamp as TerrainStamp).synced_ticks = VOLCANO_OVER_TICKS - 3
	while mound.ticks < VOLCANO_OVER_TICKS + 3:
		await _frames(1)
	var ground := _shape.field()
	var worst := 0.0
	var at_100 := 0.0
	var outside := 0.0
	for id in GroundField.COUNT:
		var x := id % GroundField.SIDE
		var z := id / GroundField.SIDE
		if not rect.has_point(Vector2i(x, z)):
			outside = maxf(outside, absf(ground.permanent[id]))
			continue
		var offset := Vector2(x, z) * TerrainRules.CELL - CENTER
		var cell := (rect.position + Vector2i.ZERO)
		var at := (z - cell.y) * rect.size.x + x - cell.x
		if is_nan(before[at]):
			continue
		var square := maxf(absf(offset.x), absf(offset.y))
		var falloff := clampf((square - 80.0) / (164.0 - 80.0), 0.0, 1.0)
		var dmap := (target - before[at]) * (1.0 - falloff) + 0.2 * float(picture.get_pixel(x - cell.x, z - cell.y).r8)
		var dent := (offset.length_squared() / 625.0 - 1.0) * 10.0 if offset.length() < 25.0 else 0.0
		var error := absf(ground.permanent[id] - (0.25 * dmap + dent))
		worst = maxf(worst, error)
		if square == 100.0 and offset.y == 0.0:
			at_100 = error
	_note("volcano end: worst error/at 100 m/outside/rev", [worst, at_100, outside, ground.rev - rev_before])
	checks["every_vertex_as_the_formula"] = worst < 0.1
	checks["flattened_100m_within_0_1"] = at_100 < 0.1
	checks["center_quarter_plus_crater"] = absf(_shape.height_at(CENTER.x, CENTER.y) - target - (0.25 * 51.0 - 10.0)) < 0.1
	checks["nothing_outside_the_33"] = outside == 0.0
	checks["two_commits_nothing_playing"] = ground.rev == rev_before + 2 and ground.live_count() == 0
	zone.queue_free()
	wizard.queue_free()
	await _frames(2)
	return _verdict("terrain_volcano_ground", checks)


## What the eruption does to the bodies around it: 1000 a second at 10 m (and fire), nothing at 60 m, lava balls at about one every 32
## ticks, and the lava ball's shot lands where it is thrown.
func _volcano_bodies() -> Dictionary:
	var checks := {}
	var wizard := _wizard(1, _far_wizard_spot(), "pyro", 8)
	var near := _tough(Vector3(CENTER.x, _shape.height_at(CENTER.x, CENTER.y + 10.0) + 0.1, CENTER.y + 10.0), 3)
	var far := _tough(Vector3(CENTER.x, _shape.height_at(CENTER.x, CENTER.y + 60.0) + 0.1, CENTER.y + 60.0), 3)
	await _frames(10)
	var zone := _volcano(wizard)
	var dropper := zone.get_node("Dropper") as ZoneDropper
	var thrown := [0]
	dropper.chosen.connect(func(_point: Vector3, _body: Node3D) -> void: thrown[0] += 1)
	var crater := zone.get_node("Crater") as TerrainStamp
	while crater.ticks < ERUPT_TICKS + 40:
		await _frames(1)
	var life := func(body: Node3D) -> float: return (body.get_node("Health") as Health).current
	var near_0: float = life.call(near)
	var far_0: float = life.call(far)
	while crater.ticks < ERUPT_TICKS + 40 + 60:
		await _frames(1)
	var lost: float = near_0 - float(life.call(near))
	var lit := false
	for child in near.get_children():
		lit = lit or child is Burning
	_note("burn: lost in 1 s at 10 m / far lost / lit", [lost, far_0 - float(life.call(far)), lit])
	checks["burns_about_1000_a_second"] = lost > 850.0 and lost < 1150.0
	checks["fire_on_the_body"] = lit
	checks["nothing_at_60m"] = far_0 - float(life.call(far)) == 0.0
	while crater.ticks < ERUPT_TICKS + 40 + 660:
		await _frames(1)
	_note("lava balls thrown in 10 s", [thrown[0]])
	checks["lava_balls_about_1_875_a_second"] = thrown[0] >= 8 and thrown[0] <= 32
	zone.queue_free()
	for node: Node in [near, far, wizard]:
		node.queue_free()
	await _frames(2)
	return _verdict("terrain_volcano_bodies", checks)


## Volcano at CENTER, as the action starts it (the cast of the test is instant: it erupts 267 ticks after it is born).
func _volcano(wizard: Node3D) -> GroundZone:
	var ground := _shape.height_at(CENTER.x, CENTER.y)
	var zone := _zone("Volcano", PackedVector3Array([Vector3(CENTER.x, ground, CENTER.y)]), wizard, 0, ERUPT_TICKS)
	zone.release()
	return zone


func _frames(count: int) -> void:
	for _i in count:
		await _host.get_tree().physics_frame
		if _case_started > 0 and Time.get_ticks_msec() - _case_started > int(CASE_CAP_S * 1000.0):
			printerr("terrain_cases: a case passed %d s: FAIL" % int(CASE_CAP_S))
			_host.get_tree().quit(1)


func _settle(planter: MeshPlanter, eye: Vector3) -> void:
	for _i in 120:
		planter.update(eye, Time.get_ticks_usec() + 4000)
		await _host.get_tree().process_frame
		if planter.pending_count() == 0 and planter.cell_count() > 0:
			return


## True when every plant of `after` stands `lift` m above the same plant of `before` (same order, same x and z).
func _lifted_by(before: Array[PackedFloat32Array], after: Array[PackedFloat32Array], lift: float) -> bool:
	for g in before.size():
		for i in before[g].size() / MeshPlanter.XFORM_STRIDE:
			var at := i * MeshPlanter.XFORM_STRIDE
			if absf(before[g][at + 3] - after[g][at + 3]) > 1e-4 or absf(after[g][at + 7] - before[g][at + 7] - lift) > 0.3:
				return false
	return true


static func _fullest_cell(flora: FloraDensity, groups: Array[Dictionary]) -> Vector2i:
	var best := Vector2i.ZERO
	var most := -1
	for cz in MeshPlanter.MAP_CELLS:
		for cx in MeshPlanter.MAP_CELLS:
			var sum := 0
			for g in groups:
				for dz in MeshPlanter.DATA_PER_CELL:
					for dx in MeshPlanter.DATA_PER_CELL:
						sum += flora.count_at(int(g["tag_index"]), cx * MeshPlanter.DATA_PER_CELL + dx, cz * MeshPlanter.DATA_PER_CELL + dz)
			if sum > most:
				most = sum
				best = Vector2i(cx, cz)
	return best


## Erupt at CENTER, as the action starts it (the cast of the test is instant: the burst comes 252 ticks after it is born).
func _erupt(wizard: Node3D) -> GroundZone:
	var ground := _shape.height_at(CENTER.x, CENTER.y)
	var zone := _zone("Erupt", PackedVector3Array([Vector3(CENTER.x, ground, CENTER.y)]), wizard, 0, BURST_TICKS)
	zone.release()
	return zone


## The ray of the collision against height_at on 50 spots around the center. True when every one agrees within 5 cm.
func _ray_matches() -> bool:
	_collision.flush()
	# What the collision holds is the ground of this very moment: take the heights now, ask the rays after the physics step.
	var rng := MatchSeed.rng(["terrain_cases", "ray"])
	var spots := []
	for _i in 50:
		var spot := CENTER + Vector2(rng.randf_range(-45.0, 45.0), rng.randf_range(-45.0, 45.0))
		spots.append([spot, _shape.height_at(spot.x, spot.y)])
	var worst := 0.0
	for pair: Array in spots:
		if not is_nan(pair[1]):
			worst = maxf(worst, absf(_ray(pair[0]) - float(pair[1])))
	_note("ray worst", [worst])
	return worst < 0.05


## Where the wizard of a test stands: on the ground, away from the action.
func _far_wizard_spot() -> Vector3:
	var at := CENTER - Vector2(150.0, 0.0)
	var ground := _shape.height_at(at.x, at.y)
	return Vector3(at.x, 1.0 if is_nan(ground) else ground + 0.5, at.y)


func _note(label: String, values: Array) -> void:
	print("terrain_cases: %s %s" % [label, values])


func _ray(spot: Vector2) -> float:
	return GroundRay.surface_y(_collision, Vector3(spot.x, 0.0, spot.y), 1, [], NAN)
