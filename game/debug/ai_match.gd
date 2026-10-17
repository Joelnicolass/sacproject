extends Node

## Bench runner of RFC-024 (024a): one reproducible match, with or without a window.
## Reads `BenchRules` (--rules=), spawns its groups through the world's UnitSpawner, lets them fight
## until a side is wiped, the match has a result or --minutes pass, and prints `AI_REPORT <json>`.
##
##   godot --headless --path game --fixed-fps 60 res://debug/ai_match.tscn -- \
##     --rules=res://debug/rules/ai_duel_seeded.tres --seed=7 --minutes=2 --out=agent/out/ai/duel_s7.json
##
## Options after `--`: rules, seed (0 = drawn), minutes, out (a .json path; AgentKit's own --out folder is ignored), events (the lines of the record),
## sample-s (seconds between position samples, 10 by default), npcs (the map's villagers on the field even if the rules say no),
## sep=brute (the old pair loop of BodySeparation, to compare its cost with the grid),
## difficulties=easy,normal (the difficulty of each AI seat in order, 024e), souls=N (starting souls of every wizard: read by
## MatchSetup.from_cli, its one owner since RFC-031 031d, and applied by HighNoon to the world's copy of these rules),
## autostart (skip the pause with a window), quit (quit at the end with a window). Headless it starts
## and quits by itself; with a window it waits in «Pendiente» for check_tick (Enter) and stays on screen.
## Determinism (RFC-032): the digest is indexed by audit.tick, but while it waits for Enter the world already runs,
## so a window run is comparable with headless only with --autostart (ventana comparable solo con --autostart).
## The three-clock bench is agent/run_determinism.sh (fixed, stress and window modes).

const REPORT_TAG := "AI_REPORT "
const MELEE_ATTACK := preload("res://scenes/world/units/melee_attack.gd")

## The world is put in the tree by code: its rules (and the seed) must exist before it enters.
@export var world_scene: PackedScene
@export var default_rules: BenchRules
@export var audit: AiAudit
@export var status_label: Label
@export var camera: Camera3D
## RFC-024 024c: the scene of an AI side (AiSide), put on the seats of the rules.
@export var ai_side_scene: PackedScene
@export var default_minutes := 2.0
@export var sample_every_s := 10.0
@export var settle_frames := 4
@export_group("Camera")
@export var camera_offset := Vector3(0.0, 30.0, 50.0)
## > 0: the bench camera keeps looking at the wizard of that slot (the AI scenes follow their wizard).
@export var follow_slot := 0

var _rules: BenchRules
var _world: Node3D
var _args: Dictionary = {}
var _minutes := 2.0
var _max_ticks := 0
var _sample_ticks := 3600
var _headless := false
var _running := false
var _finished := false
var _started_usec := 0
var _last_usec := 0
var _tick_ms := PackedFloat32Array()
var _sep_ms := PackedFloat32Array()
var _sep_bodies := 0
var _group_slots: Array[int] = []
var _watched: Array[Node3D] = []
var _report: Dictionary = {}
var _sides: Dictionary = {}
var _events: BenchEvents
var _prepared := false
var _starting := false
var _orders_at_start: Array = []
## Ticks at which the audit takes a snapshot of the numbers the criteria read (--checkpoints=minutes,minutes; 6 and 10 by default).
var _checkpoint_ticks: Array[int] = []
## «IA 1 Fácil · IA 2 Normal»: the difficulty of each AI seat, on the status label (the debug HUD of 024e).
var _seats_text := ""


func _ready() -> void:
	_args = _parse_args(OS.get_cmdline_user_args())
	_headless = DisplayServer.get_name() == "headless"
	_minutes = float(_args.get("minutes", default_minutes))
	_max_ticks = int(round(_minutes * 60.0 * 60.0))
	_sample_ticks = maxi(1, int(round(float(_args.get("sample-s", sample_every_s)) * 60.0)))
	_rules = _load_rules()
	for minute in str(_args.get("checkpoints", "6,10")).split(",", false):
		_checkpoint_ticks.append(int(round(float(minute) * 3600.0)))
	audit.keep_lines = _args.has("events")
	_apply_human_god()
	_world = world_scene.instantiate()
	_world.set("rules", _rules)
	var population := _world.get_node_or_null("%Population")
	if population:
		population.set("spawn_creatures", _rules.npcs or _args.has("npcs"))
	## 024f: the bench seats its own AI (with its audit and its pause); the roster of the world stays out.
	var roster := _world.get_node_or_null("%AiRoster")
	if roster:
		roster.set("enabled", false)
	BodySeparation.use_grid = str(_args.get("sep", "grid")) != "brute"
	BodySeparation.measure = true
	## F177 (030w-a): the two switches of the measurement (off in the product until the cut is decided).
	MELEE_ATTACK.melee_moving = _args.has("melee-moving")
	BodySeparation.share_push = _args.has("share-push")
	BodySeparation.log_push = _args.has("log-push")  # F177: attribution of the pushes of bodies in melee (off in the product)
	add_child(_world)
	var rain := _world.get_node_or_null("DropletRain")
	if rain:
		rain.set("log_hits", true)  # F148: bench logs the drops (off in the product)
	FrostWave.log_touches = true  # F149: bench logs the Silverback's breath (off in the product)
	ShotSplit.log_split = true  # F125: bench logs the Boulderdash's fan (off in the product)
	ShotStrike.log_strikes = true  # F124: bench logs the rays and the Styx's blows (off in the product)
	GroundHug.log_flight = true  # F151: bench logs the Rhinok's flight on the land (off in the product)
	SpikeWave.log_spikes = true  # F151: bench logs the Rhinok's rings of spikes (off in the product)
	ActiveAbility.log_ability = true  # R6 (030v-a): bench logs each use of an active ability (off in the product)
	AbilityEffect.log_effects = true  # F126: bench logs the Protector (off in the product)
	LifeShield.log_shields = true  # F126: bench logs the life shields (off in the product)
	Firewalking.log_walk = true  # F152: bench logs the Warmonger's walk (off in the product)
	HaloOfEarth.log_halo = true  # F127: bench logs the Rhinok's rocks (off in the product)
	Clinging.log_cling = true  # F129: bench logs the Sticky bombs and what they slow (off in the product)
	PaceFactors.log_pace = true  # F129: bench logs the factors of speed_factor (off in the product)
	Pulling.log_pull = true  # F128: bench logs the pulls (off in the product)
	BreathOfLife.log_breath = true  # F153: bench logs the Dragon's breath (off in the product)
	LightningStrike.log_bolt = true  # F130: bench logs the Storm Giant's bolts (off in the product)
	MiteHop.log_hop = true  # F156: bench logs the Bilemites hops (off in the product)
	Oiled.log_oil = true  # F155: bench logs the Viscous oil (smearing, ignite, blast) (off in the product)
	LightningCharge.log_charge = true  # F130: bench logs the Lightning Charge and the Giant's walk (off in the product)
	MeleeOnHit.log_on_hit = true  # F158: bench logs the on-hit passives (off in the product)
	MELEE_ATTACK.log_gap = true  # melee_gap_expect: bench logs each tick of a melee approach (off in the product)
	MELEE_ATTACK.log_melee = true  # F130: bench logs each blow's numbers (off in the product)
	FastRevive.log_revive = true  # F153: bench logs the fast revival (off in the product)
	DevourGrowth.log_devour = true  # F131: bench logs what the Devour gives (off in the product)
	Soul.log_souls = true  # F131: bench logs the souls eaten and the corpses they dissolve (off in the product)
	QuakeWave.log_quake = true  # F132: bench logs the Jabberocky's Quake wave (off in the product)
	Vined.log_vines = true  # F159: bench logs the Dragon's Grasping Vines (off in the product)
	_set_status(_rules.pending_text)
	var wait := _rules.start_paused and not _headless and not _args.has("autostart")
	if not wait:
		_start.call_deferred()
	elif not _rules.ai_seats.is_empty():
		## The AI scenes show their field while they wait for Enter: the wizards, the Manalith, the bodies.
		_prepare.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick") and not _running and not _finished and not _starting:
		_start()


func _load_rules() -> BenchRules:
	var loaded: Variant = load(str(_args["rules"])) if _args.has("rules") else default_rules
	var rules := (loaded as BenchRules).duplicate() as BenchRules
	if _args.has("seed"):
		rules.match_seed = int(_args["seed"])
	## --difficulties=easy,normal: the difficulty of each seat, in the order of the rules (024e; data/ai/difficulty_<name>.tres).
	if _args.has("difficulties"):
		var names := str(_args["difficulties"]).split(",")
		var seats: Array[AiSeat] = []
		for i in rules.ai_seats.size():
			var seat := rules.ai_seats[i].duplicate() as AiSeat
			if i < names.size() and not names[i].is_empty():
				seat.difficulty = load("res://data/ai/difficulty_%s.tres" % names[i]) as AiDifficulty
			seats.append(seat)
		rules.ai_seats = seats
	return rules


func _start() -> void:
	_starting = true
	if not _prepared:
		await _prepare()
	_begin()


## Puts everything on the field: the AI wizards, the structures, the groups, the watchers and the sides (paused).
func _prepare() -> void:
	if _prepared:
		return
	_prepared = true
	for _frame in settle_frames:
		await get_tree().physics_frame
	var terrain := _world.get_node("Terrain")
	var spawner := _world.get_node("UnitSpawner")
	if not _rules.ai_seats.is_empty():
		await _seat_ais()
	_place_structures()
	for group in _rules.groups:
		if not _group_slots.has(group.slot):
			_group_slots.append(group.slot)
		var type := GameData.creature(group.tag)
		var label := type.display_name if type else group.tag
		var made: Array[Node3D] = []
		for index in group.count:
			var column := index % group.columns
			var row := floori(float(index) / group.columns)
			var rows := ceili(float(group.count) / group.columns)
			var x := _rules.anchor.x + group.offset_m + (row - (rows - 1) * 0.5) * group.spacing_m
			var z := _rules.anchor.z + group.offset_z_m + (column - (group.columns - 1) * 0.5) * group.spacing_m
			var yaw := atan2(group.facing_x, 0.0)
			if group.near_slot > 0:
				var spot := _near_spot(group, index, terrain)
				x = spot.x
				z = spot.y
				yaw = spot.w
			var ground := float(terrain.call("ground_height", x, z))
			var unit: Node3D = spawner.call("spawn_unit", {
				"tag": group.tag, "label": label, "slot": group.slot,
				"x": x, "y": (0.0 if is_nan(ground) else ground) + 0.2, "z": z,
				"yaw": yaw,
			})
			if group.pacifist and unit.get("type") is CreatureType:
				var calm := (unit.get("type") as CreatureType).duplicate() as CreatureType
				calm.aggressiveness = 0
				unit.set("type", calm)
			if group.holds_still:
				unit.set("idle_aggro", false)
			if group.health_fraction < 1.0:
				var health := unit.get_node("Health") as Health
				health.current = health.maximum * group.health_fraction
			audit.watch_unit(unit)
			_watched.append(unit)
			made.append(unit)
		if group.order in ["advance_altar", "attack_structure", "attack_unit", "ability"]:
			_orders_at_start.append([group, made])
	for wizard in get_tree().get_nodes_in_group("wizard"):
		var purse := wizard.get_node_or_null("SoulPurse")
		if purse:
			audit.watch_purse(int(wizard.get("owner_slot")), purse)
		_watched.append(wizard as Node3D)
	for npc in get_tree().get_nodes_in_group("npc"):
		audit.watch_unit(npc)
		_watched.append(npc as Node3D)
	var souls := _world.get_node("SoulSystem")
	souls.connect("soul_spawned", audit.watch_soul)
	audit.watch_sources(souls, _world.get_node("SacrificeSystem"))
	## The creatures that appear later (a summon of the AI, a bench event) are watched from now on.
	_world.get_node("%Units").child_entered_tree.connect(_on_unit_entered)
	_frame_camera()
	audit.watch_world(_world)
	_start_ais()
	_events = BenchEvents.new(_world, audit, _sides, _rules)


## The clock starts: the orders of the scene, the AI sides, the record.
func _begin() -> void:
	for pair in _orders_at_start:
		_order_advance(pair[0], pair[1])
	_orders_at_start.clear()
	for slot in _sides:
		var side: AiSide = _sides[slot]
		side.active = side.seat.start_active
	BodySeparation.take_us()
	audit.start()
	_started_usec = Time.get_ticks_usec()
	_last_usec = _started_usec
	_running = true
	print("ai_match en marcha: semilla %d, %.1f min, %d unidades" % [MatchSeed.current, _minutes, _watched.size()])


func _physics_process(_delta: float) -> void:
	if not _running:
		return
	if _events != null:
		_events.step(audit.tick)
	var now := Time.get_ticks_usec()
	_tick_ms.append(float(now - _last_usec) / 1000.0)
	_last_usec = now
	_sep_ms.append(float(BodySeparation.take_us()) / 1000.0)
	if _checkpoint_ticks.has(audit.tick):
		audit.checkpoint(str(audit.tick / 3600))
	_sep_bodies += get_tree().get_nodes_in_group("unit").size() + get_tree().get_nodes_in_group("wizard").size()
	if audit.tick > 0 and audit.tick % _sample_ticks == 0:
		audit.sample(_watched)
	var verdict := _verdict()
	if not verdict.is_empty():
		_finish(int(verdict[0]), str(verdict[1]))


## [winner, reason] once the match is over, [] while it goes on.
func _verdict() -> Array:
	var state := _world.get_node_or_null("Match") as MatchState
	if state and state.ended:
		return [state.winner_slot, "match_state"]
	if _group_slots.size() >= 2 and not _rules.ignore_annihilation:
		var alive: Array[int] = []
		for slot in _group_slots:
			if audit.alive_of(slot) > 0:
				alive.append(slot)
		if alive.is_empty():
			return [0, "mutual_annihilation"]
		if alive.size() == 1:
			return [alive[0], "annihilation"]
	if audit.tick >= _max_ticks:
		return [0, "time"]
	return []


func _finish(winner: int, reason: String) -> void:
	_running = false
	_finished = true
	audit.sample(_watched)
	audit.stop()
	for slot in _sides:
		var side: AiSide = _sides[slot]
		audit.set_extra(int(slot), "ai_ms", side.ms_stats())
		audit.set_extra(int(slot), "ai_slot_ms", side.slot_stats())
		audit.set_extra(int(slot), "ai_orders", side.port.orders_issued)
		audit.set_extra(int(slot), "ai_order_stats", side.port.order_stats)
		audit.set_extra(int(slot), "ai_casts_started", side.brain.casts_started)
		## 024e: the difficulty and what the side read of bodies it did not see (0 without perfect information).
		audit.set_extra(int(slot), "difficulty", {
			"name": side.difficulty.display_name, "file": side.difficulty.resource_path,
			"periods": Array(side.profile.slot_periods), "aggression": side.profile.aggression,
			"delay_ticks": side.port.delay_ticks, "perfect_information": side.perception.perfect_information,
			"resource_bonus": side.difficulty.resource_bonus})
		audit.set_extra(int(slot), "unseen_target_reads", side.port.unseen_target_reads)
		audit.set_extra(int(slot), "unseen_state_reads", side.perception.unseen_reads)
		audit.set_extra(int(slot), "forgotten", side.perception.forgotten)
		audit.set_extra(int(slot), "delayed_requests", side.port.delayed)
		audit.set_extra(int(slot), "lapsed_requests", side.port.lapsed)
		audit.set_extra(int(slot), "lapse_reasons", side.port.lapse_reasons)
		var state := side.summary()
		state["wizard"] = _wizard_info(side.perception.find(side.wizard))
		audit.set_extra(int(slot), "ai_state", state)
	var wall_s := float(Time.get_ticks_usec() - _started_usec) / 1e6
	_report = {
		"seed": MatchSeed.current,
		"minutes": _minutes,
		"winner_slot": winner,
		"end_tick": audit.tick,
		"end_reason": audit.end_reason(winner) if reason == "match_state" else reason,
		"digest": audit.digest(),
		"events": audit.line_count,
		"rules": str(_args.get("rules", _rules.resource_path)),
		"physics_engine": str(ProjectSettings.get_setting("physics/3d/physics_engine", "DEFAULT")),
		"godot": Engine.get_version_info().get("string", ""),
		"sides": audit.sides_report(),
		"wall_s": snappedf(wall_s, 0.01),
		"tick_ms": _tick_stats(),
		"sep_ms": _sep_stats(),
		"separation": "grid" if BodySeparation.use_grid else "brute",
		"npc_alive_end": audit.npc_alive(),
		"checkpoints": audit.checkpoints(),
		"mem_static_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1),
	}
	var nav := _world.get_tree().get_first_node_in_group(NavService.GROUP) as NavService
	if nav != null:
		_report["nav"] = {"rebuilds": nav.rebuilds, "land_builds": nav.grid.land_builds, "last_build_ms": snappedf(nav.grid.build_ms, 0.1), "free_nodes": nav.grid.free_count}
	if _events != null:
		_report["probes"] = _events.report()
	var population := _world.get_node_or_null("%Population")
	if population:
		var pop: Dictionary = population.get("report")
		_report["npc_spawned"] = pop.get("npc_spawned", {})
		_report["buildings_placed"] = pop.get("buildings_placed", 0)
		_report["shelters"] = pop.get("shelters", 0)
	var text := JSON.stringify(_report)
	print(REPORT_TAG + text)
	if str(_args.get("out", "")).ends_with(".json"):
		_write(_absolute(str(_args["out"])), JSON.stringify(_report, "\t"))
	if _args.has("events"):
		_write(_absolute(str(_args["events"])), "\n".join(audit.lines) + "\n")
	_set_status("Terminado · semilla %d" % MatchSeed.current)
	if _headless or _args.has("quit"):
		get_tree().quit()


func _tick_stats() -> Dictionary:
	if _tick_ms.is_empty():
		return {}
	var sorted := _tick_ms.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += value
	return {
		"mean": snappedf(total / sorted.size(), 0.001),
		"p99": snappedf(sorted[int(sorted.size() * 0.99)], 0.001),
		"max": snappedf(sorted[sorted.size() - 1], 0.001),
	}


## `sep_ms` (BodySeparation.resolve summed over a tick): the mean, p99 and max over the run and the mean bodies.
func _sep_stats() -> Dictionary:
	if _sep_ms.is_empty():
		return {}
	var sorted := _sep_ms.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += value
	return {
		"mean": snappedf(total / sorted.size(), 0.001),
		"p99": snappedf(sorted[int(sorted.size() * 0.99)], 0.001),
		"max": snappedf(sorted[sorted.size() - 1], 0.001),
		"bodies_mean": snappedf(float(_sep_bodies) / sorted.size(), 0.1),
	}


func _process(_delta: float) -> void:
	if _running and follow_slot > 0 and camera != null and not _headless:
		var target := _wizard_of(follow_slot)
		if target != null:
			camera.global_position = target.global_position + camera_offset
			camera.look_at(target.global_position + Vector3.UP * 1.5, Vector3.UP)
	if _running:
		_set_status("Corriendo · %.0f s · semilla %d%s" % [audit.tick / 60.0, MatchSeed.current, _seats_text])
	elif not _finished:
		_set_status("%s · semilla %d%s · Enter para largar" % [_rules.pending_text, MatchSeed.current, _seats_text])


func _set_status(text: String) -> void:
	if status_label and status_label.text != text:
		status_label.text = text


## RFC-030 030b: the god of the human wizard goes in the local pick before the world spawns him (as _seat_ais does with the seats).
func _apply_human_god() -> void:
	if _rules.human_god == &"":
		return
	var chosen := SacrificeFlow.pick.duplicate()
	chosen["god"] = str(_rules.human_god)
	SacrificeFlow.pick = chosen
	if SacrificeFlow.slot_picks.has(1):
		var seated: Dictionary = SacrificeFlow.slot_picks[1].duplicate()
		seated["god"] = str(_rules.human_god)
		SacrificeFlow.slot_picks[1] = seated
		SacrificeFlow.slot_picks_changed.emit()


## The seats of the AI (RFC-024 §4, 024c in the debug scenes; the production roster is 024f): the pick of the seat goes where the
## wizards read it, the WizardSpawner makes the wizard of its slot, and a few frames pass while he seats himself on the ground.
func _seat_ais() -> void:
	for seat in _rules.ai_seats:
		var wizard_type := GameData.wizard(seat.wizard)
		SacrificeFlow.slot_picks[seat.slot] = {
			"wizard": seat.wizard, "model": wizard_type.model if wizard_type != null else "jnwr", "god": str(seat.god)}
		SacrificeFlow.slot_picks_changed.emit()
		_world.get_node("WizardSpawner").call("spawn_slot", seat.slot)
	for _frame in settle_frames + 16:
		await get_tree().physics_frame
	_move_ai_wizards()


func _place_structures() -> void:
	var spawner := _world.get_tree().get_first_node_in_group("structure_spawner")
	for structure in _rules.structures:
		var fount := _world.get_node_or_null("MapProps/Founts/" + structure.fount)
		var wizard := _wizard_of(structure.slot)
		if fount == null or wizard == null or spawner == null:
			push_warning("ai_match: no se pudo poner la estructura %s en %s" % [structure.spell_tag, structure.fount])
			continue
		var spell := GameData.spell(structure.spell_tag)
		var index := GameData.gods().find(str(wizard.get("god")))
		var model: String = spell.structures[maxi(index, 0)] if spell != null and spell.structures.size() > maxi(index, 0) else ""
		spawner.call("spawn_structure", {
			"x": fount.global_position.x, "y": fount.global_position.y, "z": fount.global_position.z,
			"yaw": 0.0, "slot": structure.slot, "model": model, "spell_tag": structure.spell_tag,
			"manafount_path": str(fount.get_path()),
		})


func _wizard_of(slot: int) -> Node3D:
	for wizard in get_tree().get_nodes_in_group("wizard"):
		if int(wizard.get("owner_slot")) == slot:
			return wizard as Node3D
	return null


## A spot `near_distance_m` from the wizard of `near_slot`, towards the other wizard turned `near_angle_deg`, the group in
## a row of its columns: (x, z, 0, yaw) in the components x, y, z, w.
func _near_spot(group: BenchGroup, index: int, terrain: Node) -> Vector4:
	var base := _wizard_of(group.near_slot)
	var other: Node3D
	for wizard in get_tree().get_nodes_in_group("wizard"):
		if int(wizard.get("owner_slot")) != group.near_slot:
			other = wizard as Node3D
	var dir := Vector3(0.0, 0.0, 1.0)
	if base != null and other != null:
		dir = other.global_position - base.global_position
		dir.y = 0.0
		dir = dir.normalized()
	dir = dir.rotated(Vector3.UP, deg_to_rad(group.near_angle_deg))
	var side := Vector3(-dir.z, 0.0, dir.x)
	var column := index % group.columns
	var row := floori(float(index) / group.columns)
	var origin := base.global_position if base != null else Vector3.ZERO
	var at := BenchEvents.find_spot(_world, origin, dir, group.near_distance_m + row * group.spacing_m, 0.0)
	if is_nan(at.x):
		push_warning("ai_match: no hay un lugar a %.0f m del mago %d" % [group.near_distance_m, group.near_slot])
		at = origin + dir * group.near_distance_m
	at += side * (column - (group.columns - 1) * 0.5) * group.spacing_m
	return Vector4(at.x, at.z, 0.0, atan2(-dir.x, -dir.z))


func _order_advance(group: BenchGroup, units: Array[Node3D]) -> void:
	if group.order == "ability":
		## F137: each body uses its active ability on itself when the clock starts (an Earthfling's Rockform), like a click.
		for unit in units:
			unit.call("use_ability", unit.global_position, null)
		return
	if group.order == "attack_unit":
		## F136: an attack on the creature of `order_slot` closest to the group's first body (Orders.apply_for, like a click).
		var foe := _closest_unit_of(group.order_slot, units[0].global_position, group.order_farthest) if not units.is_empty() else null
		if foe != null:
			_world.get_node("%Orders").call("apply_for", group.slot, units, "attack", foe.global_position, foe, 0.0)
		return
	if group.order == "attack_structure":
		## An attack on the first structure (a Manalith) of `order_slot`: Orders.apply_for, like a human's order on a click.
		var structure: Node3D
		for node in get_tree().get_nodes_in_group("structure"):
			if int(node.get("owner_slot")) == group.order_slot and not node.is_in_group(MapBuilding.GROUP):
				structure = node as Node3D
				break
		if structure != null:
			_world.get_node("%Orders").call("apply_for", group.slot, units, "attack", structure.global_position, structure, 0.0)
		return
	var altar: Node3D
	for node in get_tree().get_nodes_in_group(Altar.GROUP):
		if int(node.get("owner_slot")) == group.order_slot:
			altar = node as Node3D
	if altar == null:
		return
	_world.get_node("%Orders").call("apply_for", group.slot, units, "advance", altar.global_position, null, 0.0)


func _closest_unit_of(slot: int, from: Vector3, farthest := false) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("unit"):
		var unit := node as Node3D
		if unit == null or int(unit.get("owner_slot")) != slot:
			continue
		var d := unit.global_position.distance_to(from) * (-1.0 if farthest else 1.0)
		if d < best_d:
			best_d = d
			best = unit
	return best


## A side of the AI for each seat, started with the match (audit.start follows).
func _start_ais() -> void:
	for seat in _rules.ai_seats:
		var wizard := _wizard_of(seat.slot)
		if wizard == null or ai_side_scene == null:
			push_warning("ai_match: no hay mago o escena de IA para el slot %d" % seat.slot)
			continue
		var side := (seat.side_scene if seat.side_scene != null else ai_side_scene).instantiate() as AiSide
		side.name = "AiSide%d" % seat.slot
		side.audit = audit
		add_child(side)
		side.setup(_world, wizard, seat)
		_sides[seat.slot] = side
		## a seat with its own side scene is the bench bot (debug/ai_side_trivial.tscn): it has no difficulty to show
		if seat.side_scene != null:
			_seats_text += " · %d Bot trivial" % seat.slot
		else:
			_seats_text += " · IA %d %s" % [seat.slot, side.difficulty.display_name]


func _on_unit_entered(node: Node) -> void:
	audit.watch_unit.call_deferred(node)
	_watched.append.call_deferred(node)


func _frame_camera() -> void:
	if camera == null or _headless:
		return
	var terrain := _world.get_node("Terrain")
	var ground := float(terrain.call("ground_height", _rules.anchor.x, _rules.anchor.z))
	var center := Vector3(_rules.anchor.x, 0.0 if is_nan(ground) else ground, _rules.anchor.z)
	camera.global_position = center + camera_offset
	camera.look_at(center, Vector3.UP)
	camera.current = true


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("no se pudo escribir %s" % path)
		return
	file.store_string(text)


## Relative paths are relative to the project, as in the command of RFC-024 §5.2.
func _absolute(path: String) -> String:
	if path.is_absolute_path():
		return path
	return ProjectSettings.globalize_path("res://").path_join(path)


static func _parse_args(raw: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in raw:
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var cut := body.find("=")
		if cut < 0:
			out[body] = true
		else:
			out[body.substr(0, cut)] = body.substr(cut + 1)
	return out


## BenchRules.ai_start_near_altar_of: the AI wizards start `ai_start_distance_m` from the altar of that slot (ai_endgame: the AI
## arrives at the end of the match without the half hour of walking). The wizard is warped there like a Teleport.
func _move_ai_wizards() -> void:
	if _rules.human_start_near_altar_of > 0:
		_warp_near_altar(_wizard_of(1), _rules.human_start_near_altar_of, _rules.human_start_distance_m)
	if _rules.ai_start_near_altar_of <= 0:
		return
	for seat in _rules.ai_seats:
		if seat.slot != _rules.ai_start_near_altar_of:
			_warp_near_altar(_wizard_of(seat.slot), _rules.ai_start_near_altar_of, _rules.ai_start_distance_m)


## The wizard is warped `distance_m` from the altar of `altar_slot`, on his side of it, like a Teleport.
func _warp_near_altar(wizard: Node3D, altar_slot: int, distance_m: float) -> void:
	var altar: Node3D
	for node in get_tree().get_nodes_in_group(Altar.GROUP):
		if int(node.get("owner_slot")) == altar_slot:
			altar = node as Node3D
	if altar == null or wizard == null:
		return
	var toward := wizard.global_position - altar.global_position
	toward.y = 0.0
	var at := BenchEvents.find_spot(_world, altar.global_position, toward.normalized(), distance_m, 0.0)
	if is_nan(at.x):
		## Some altars stand on a rise the strict search rejects all around (High Noon's slot 2): any ground at that distance.
		at = BenchEvents.find_spot(_world, altar.global_position, toward.normalized(), distance_m, 0.0, false)
	if is_nan(at.x):
		push_warning("ai_match: no hay un lugar a %.0f m del altar del slot %d" % [distance_m, altar_slot])
		return
	wizard.call("warp_to", at)


## Diagnostic of the bench (moved out of AiSide in the 024d fix): what an AI wizard is doing, for the report: where, walking or not, the last order the brain gave, the head of the cast queue, mana.
static func _wizard_info(t: AiTrack) -> Dictionary:
	if t == null or not t.is_valid():
		return {}
	var follower := t.node.get_node_or_null("PathFollower")
	var head := ""
	if not t.cast_queue.is_empty():
		var spell: Resource = (t.cast_queue[0] as Dictionary)["spell"]
		head = str(spell.get("tag")) if spell != null else ""
	var near := []
	for g in ["unit", "wizard", "corpse"]:
		for n in t.node.get_tree().get_nodes_in_group(g):
			if n != t.node and (n as Node3D).global_position.distance_to(t.node.global_position) < 7.0:
				near.append("%s(%s)" % [n.name, g])
	var cols := []
	if t.node is CharacterBody3D:
		for i in (t.node as CharacterBody3D).get_slide_collision_count():
			var c := (t.node as CharacterBody3D).get_slide_collision(i)
			cols.append(str(c.get_collider().name) if c.get_collider() != null else "?")
	return {
		"near7": near, "slide": cols, "vel": str((t.node as CharacterBody3D).velocity) if t.node is CharacterBody3D else "",
		"at": AiAudit.fmt(t.node.global_position), "walking": bool(t.node.call("is_walking")), "ord_state": t.ord_state, "ord_pos": AiAudit.fmt(t.ord_pos),
		"queue_head": head, "queue": t.cast_queue.size(), "mana": snappedf(AiPerception._mana_now(t.node), 0.1),
		"waypoints": str(follower.get("waypoints")) if follower != null else "", "follower_active": bool(follower.get("active")) if follower != null else false,
		"record_target": str(t.record.target.node.name) if t.record != null and t.record.target != null and t.record.target.is_valid() else "-",
		"next_reissue": t.next_reissue, "age": t.age,
	}
