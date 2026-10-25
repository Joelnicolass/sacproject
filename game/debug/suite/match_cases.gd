extends RefCounted

## RFC-020a cases of rules_suite: altar collapse, defeat, snapshot and banner. No physics frames are
## needed: the clocks are advanced by hand with MatchState.tick().
## `run(host)` builds small worlds under `host` and removes them when it ends.

const ALTAR_SCENE := preload("res://scenes/map/props/altar.tscn")
const MATCH_SCENE := preload("res://scenes/match/match_state.tscn")
const BANNER_SCENE := preload("res://scenes/ui/hud/match_result.tscn")
const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const RULES := preload("res://data/match_rules.tres")


func run(host: Node3D) -> Dictionary:
	var out := {}
	out["altar_collapse"] = _altar_collapse(host)
	out["match_snapshot"] = _match_snapshot(host)
	out["match_banner"] = _match_banner(host)
	return out


## begin_altar_collapse(2, 1) → at altar_collapse_s the altar is DESTROYED and out of "altar",
## slot 2 is defeated, slot 1 wins and the creatures of slot 2 died.
func _altar_collapse(host: Node3D) -> Dictionary:
	var root := _world(host, true)
	var state := root.get_node("Match") as MatchState
	var altar1 := root.get_node("Altar1") as Altar
	var altar2 := root.get_node("Altar2") as Altar
	var mine := _unit(root, 1)
	var theirs := _unit(root, 2)
	var checks := {}
	checks["both_standing"] = altar1.is_standing() and altar2.is_standing()
	checks["in_group"] = altar2.is_in_group(Altar.GROUP)
	checks["started"] = state.begin_altar_collapse(2, 1)
	checks["collapsing"] = altar2.state == Altar.State.COLLAPSING and altar2.is_in_group(Altar.GROUP)
	checks["collapse_plays"] = altar2.collapse.is_playing()
	var seconds := 0.0
	var step := 0.5
	while altar2.state == Altar.State.COLLAPSING and seconds < 30.0:
		state.tick(step)
		seconds += step
	checks["seconds"] = seconds
	checks["seconds_ok"] = is_equal_approx(seconds, RULES.altar_collapse_s) or absf(seconds - RULES.altar_collapse_s) <= step
	checks["destroyed"] = altar2.state == Altar.State.DESTROYED
	checks["out_of_group"] = not altar2.is_in_group(Altar.GROUP)
	checks["no_collision"] = altar2.collision_layer == 0
	checks["no_model"] = not altar2.visuals.visible
	checks["no_mana"] = not altar2.mana_source.is_in_group(Altar.MANA_GROUP) and altar2.mana_source.process_mode == Node.PROCESS_MODE_DISABLED
	checks["site_not_standing"] = not altar2.site.is_standing()
	checks["defeated_2"] = state.is_defeated(2) and not state.is_defeated(1)
	checks["winner_1"] = state.ended and state.winner_slot == 1
	checks["creature_2_dead"] = theirs.is_dead()
	checks["creature_1_alive"] = not mine.is_dead()
	checks["altar_1_intact"] = altar1.is_standing() and altar1.is_in_group(Altar.GROUP) and altar1.visuals.visible
	var ok := true
	for key in checks:
		if checks[key] is bool and not checks[key]:
			ok = false
	root.queue_free()
	checks["ok"] = ok
	return checks


## to_snapshot() applied to another MatchState (a client, with no rule) leaves the same states and winner.
func _match_snapshot(host: Node3D) -> Dictionary:
	var server_root := _world(host, true)
	var server := server_root.get_node("Match") as MatchState
	var client_root := _world(host, false)
	var client := client_root.get_node("Match") as MatchState
	var checks := {}
	server.begin_altar_collapse(2, 1)
	server.tick(4.0)
	var wire: Variant = bytes_to_var(var_to_bytes(server.to_snapshot()))
	client.apply_snapshot(wire as Dictionary)
	var client_altar2 := client_root.get_node("Altar2") as Altar
	checks["midway_state"] = client_altar2.state == Altar.State.COLLAPSING
	checks["midway_visual"] = client_altar2.collapse.is_playing()
	checks["midway_no_result"] = not client.ended
	server.tick(RULES.altar_collapse_s)
	wire = bytes_to_var(var_to_bytes(server.to_snapshot()))
	client.apply_snapshot(wire as Dictionary)
	var same := true
	for slot in [1, 2]:
		var a := server_root.get_node("Altar%d" % slot) as Altar
		var b := client_root.get_node("Altar%d" % slot) as Altar
		if a.state != b.state:
			same = false
	checks["same_states"] = same
	checks["destroyed_on_client"] = client_altar2.is_destroyed() and not client_altar2.is_in_group(Altar.GROUP)
	checks["same_defeated"] = client.defeated_slots == server.defeated_slots and client.is_defeated(2)
	checks["same_winner"] = client.winner_slot == server.winner_slot and client.winner_slot == 1 and client.ended
	var ok := true
	for key in checks:
		if not checks[key]:
			ok = false
	checks["ok"] = ok
	server_root.queue_free()
	client_root.queue_free()
	return checks


## The banner says «Victoria» to the winner, «Derrota» to the defeated, nothing to the dedicated (slot 0).
func _match_banner(host: Node3D) -> Dictionary:
	var root := _world(host, true)
	var state := root.get_node("Match") as MatchState
	var banner := BANNER_SCENE.instantiate() as MatchResultBanner
	banner.match_state = state
	root.add_child(banner)
	var checks := {}
	checks["empty_before"] = banner.text_for(1).is_empty() and banner.text_for(2).is_empty()
	state.begin_altar_collapse(2, 1)
	state.tick(RULES.altar_collapse_s)
	checks["slot1"] = banner.text_for(1)
	checks["slot2"] = banner.text_for(2)
	checks["slot0"] = banner.text_for(0)
	checks["ok"] = checks["slot1"] == "Victoria" and checks["slot2"] == "Derrota" and checks["slot0"] == ""
	root.queue_free()
	return checks


## Two altars (slots 1 and 2) and a Match. `with_rule` false: a MatchState alone, as a client has it.
func _world(host: Node3D, with_rule: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "MatchCase"
	host.add_child(root)
	for slot in [1, 2]:
		var altar := ALTAR_SCENE.instantiate() as Altar
		altar.name = "Altar%d" % slot
		altar.owner_slot = slot
		altar.position = Vector3(slot * 500.0, 0.0, 0.0)
		root.add_child(altar)
	var state: MatchState
	if with_rule:
		state = MATCH_SCENE.instantiate() as MatchState
	else:
		state = MatchState.new()
	state.name = "Match"
	state.world = root
	state.rules = RULES
	root.add_child(state)
	return root


func _unit(root: Node3D, slot: int) -> UnitBody:
	var type := GameData.creature("nmuh")
	var unit := UNIT_SCENE.instantiate() as UnitBody
	unit.name = "Unit%d" % slot
	unit.owner_slot = slot
	unit.type = GameData.creature("nmuh")
	unit.model = str(type.model) if type else ""
	unit.rules = RULES
	unit.position = Vector3(slot * 500.0 + 30.0, 0.0, 0.0)
	root.add_child(unit)
	return unit
