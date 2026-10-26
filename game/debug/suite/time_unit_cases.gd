extends RefCounted

## 055u cases of rules_suite: every time knob a human edits is written in seconds and still lasts exactly the ticks it lasted
## when it was written in ticks. For each converted field (the script's default, an override in a scene or a .tres) the
## seconds at 60 Hz give the old ticks; run again at 30 Hz they give a real duration within one tick of the old one.
## The AI's ages (runs of the clock's perception job) are checked the same way, also at a slower difficulty.

const SIDE := preload("res://scenes/ai/ai_side.tscn")
const EASY := preload("res://data/ai/difficulty_easy.tres")
const RULES := preload("res://data/match_rules.tres")

## [where, property, ticks it had]. `where` is a script (its default), a scene (every node that sets it) or a .tres.
const FIELDS := [
	["res://scenes/units/corpse.gd", "fall_s", 55],
	["res://scenes/units/passives/fire_shield.gd", "fire_every_s", 5],
	["res://scenes/units/strikes/ray_strike.gd", "period_s", 4],
	["res://scenes/units/strikes/warmonger_gun.tscn", "period_s", 4],
	["res://scenes/units/vision/vision.gd", "forget_s", 384],
	["res://scenes/units/vision/vision.gd", "refresh_s", 30],
	["res://scenes/units/impacts/burn_impact.gd", "fixed_s", 60],
	["res://scenes/units/impacts/burn_impact.gd", "fire_every_s", 10],
	["res://scenes/units/impacts/spike_wave.gd", "life_s", 90],
	["res://scenes/units/impacts/spike_wave.gd", "damage_at_s", [14, 29, 44, 59, 89]],
	["res://scenes/units/impacts/stun_impact.gd", "cooldown_s", 480],
	["res://scenes/units/impacts/pushback.gd", "duration_s", 40],
	["res://scenes/units/afflictions/frozen.gd", "max_cooldown_s", 600],
	["res://scenes/units/afflictions/oiled.gd", "fire_s", 60],
	["res://scenes/units/afflictions/firewalking.gd", "walk_s", 60],
	["res://scenes/units/afflictions/firewalking.gd", "trail_every_s", 2],
	["res://scenes/units/afflictions/petrified.gd", "knock_cooldown_s", 240],
	["res://scenes/units/afflictions/looks/vine_look.gd", "grow_s", 60],
	["res://scenes/units/afflictions/looks/body_box_look.gd", "grow_s", 30],
	["res://scenes/units/afflictions/looks/rings_look.gd", "every_s", 25],
	["res://scenes/units/abilities/lightning_strike.gd", "travel_s", 12],
	["res://scenes/units/abilities/pull_thread.gd", "grow_s", 20],
	["res://scenes/units/abilities/pull_thread.gd", "reshape_s", 6],
	["res://scenes/units/abilities/pull_thread.gd", "ramp_s", 30],
	["res://scenes/units/abilities/pull_thread.gd", "wait_s", 30],
	["res://scenes/units/abilities/pull_thread.gd", "max_life_s", 2400],
	["res://scenes/units/abilities/cage_thread.tscn", "reshape_s", 6],
	["res://scenes/units/abilities/cage_thread.tscn", "ramp_s", 30],
	["res://scenes/units/abilities/divine_sight_eye.gd", "rising_s", 45],
	["res://scenes/units/abilities/divine_sight_eye.gd", "refresh_s", 30],
	["res://scenes/units/abilities/divine_sight_eye.gd", "frame_s", 8],
	["res://scenes/units/status/poisoning.gd", "mana_block_s", 120],
	["res://scenes/units/status/poisoning.gd", "infection_cooldown_extra_s", 180],
	["res://scenes/units/status/poisoning.gd", "fx_every_s", 30],
	["res://scenes/units/abilities/quake_wave.gd", "cooldown_s", 480],
	["res://scenes/units/abilities/quake_wave.gd", "life_s", 30],
	["res://scenes/units/abilities/pull.gd", "pull_s", 25],
	["res://scenes/units/abilities/pull.gd", "stun_s", 480],
	["res://scenes/units/abilities/cage_pull.tscn", "pull_s", 25],
	["res://scenes/units/abilities/cage_pull.tscn", "stun_s", 480],
	["res://scenes/units/abilities/web_pull.tscn", "pull_s", 25],
	["res://scenes/units/abilities/web_pull.tscn", "stun_s", 480],
	["res://scenes/units/abilities/fast_revive.gd", "revive_s", 150],
	["res://scenes/units/abilities/fast_revive.gd", "rise_s", 75],
	["res://scenes/units/abilities/revive_slow.tscn", "revive_s", 300],
	["res://scenes/units/abilities/revive_slow.tscn", "rise_s", 150],
	["res://scenes/units/abilities/ability_effect.gd", "windup_s", 0],
	["res://scenes/units/abilities/bilemites.tscn", "windup_s", 94],
	["res://scenes/units/abilities/sticky_bomb.tscn", "windup_s", 94],
	["res://scenes/units/abilities/viscous_oil.tscn", "windup_s", 94],
	["res://scenes/units/abilities/firewalk.tscn", "windup_s", 150],
	["res://scenes/units/abilities/breath_of_life_ability.tscn", "windup_s", 52],
	["res://scenes/units/abilities/halo_of_earth.gd", "ground_grace_s", 35],
	["res://scenes/units/abilities/halo_of_earth.gd", "life_s", 2100],
	["res://scenes/units/attacks/droplet_rain.gd", "max_fall_s", 600],
	["res://scenes/units/attacks/mite_hop.gd", "rest_s", 30],
	["res://scenes/units/attacks/ignite_touch.gd", "fire_s", 30],
	["res://scenes/units/attacks/ground_hug_flight.gd", "spike_every_s", 6],
	["res://scenes/units/weapons/ranged_weapon.gd", "facing_s", 4],
	["res://scenes/spells/walls/fence_posts.gd", "period_s", 32],
	["res://scenes/spells/walls/fence_posts.gd", "birth_s", 16],
	["res://scenes/spells/walls/wall_scars.gd", "every_s", 4],
	["res://scenes/spells/walls/spell_wall.gd", "grow_s", 240],
	["res://scenes/spells/walls/firewall.tscn", "grow_s", 240],
	["res://scenes/spells/walls/vinewall.tscn", "grow_s", 240],
	["res://scenes/spells/walls/wall_of_spikes.tscn", "grow_s", 240],
	["res://scenes/spells/walls/wailing_wall.tscn", "grow_s", 180],
	["res://scenes/spells/walls/fence.tscn", "grow_s", 176],
	["res://scenes/spells/walls/wall_touch.gd", "stun_cooldown_s", 0],
	["res://scenes/spells/walls/wall_of_spikes.tscn", "stun_cooldown_s", 480],
	["res://scenes/spells/walls/wall_spirit.gd", "trail_s", 90],
	["res://scenes/spells/carrier/charm.tscn", "trail_s", 60],
	["res://scenes/spells/zones/zone_blast.gd", "burn_s", 60],
	["res://scenes/spells/zones/zone_heat.gd", "burn_s", 0],
	["res://scenes/spells/zones/volcano_zone.tscn", "burn_s", 30],
	["res://scenes/spells/zones/zone_stun_ring.gd", "cooldown_s", 480],
	["res://scenes/spells/zones/rift_ribbon.gd", "trail_s", 120],
	["res://scenes/spells/zones/volcano_look.gd", "lava_frame_s", 4],
	["res://scenes/spells/zones/volcano_look.gd", "pulse_s", 90],
	["res://scenes/spells/wards/ward.gd", "grow_s", 15],
	["res://scenes/spells/wards/healing_aura.tscn", "grow_s", 30],
	["res://scenes/spells/drops/drop_blast.gd", "burn_s", 60],
	["res://scenes/spells/drops/drop_blast.gd", "stun_s", 0],
	["res://scenes/spells/drops/meteor.tscn", "stun_s", 480],
	["res://scenes/spells/animate_dead/animate_dead_fx.gd", "every_s", 2],
	["res://scenes/spells/carrier/carrier_pulse.gd", "stun_s", 480],
	["res://scenes/spells/carrier/spell_carrier.gd", "roundtrip_s", 540],
	["res://scenes/spells/chain/chain_strike.gd", "travel_s", 12],
	["res://scenes/spells/chain/chain_hop.gd", "hop_s", 20],
	["res://scenes/spells/zones/rift_spawner.gd", "every_s", 20],
	["res://scenes/spells/zones/rift_spirit.gd", "launch_s", 20],
	["res://scenes/spells/wards/aura_impact.gd", "every_s", 20],
	["res://scenes/spells/drops/frog_hop.gd", "burst_after_s", 20],
	# 063D redefined it (each touched chunk waits at most refresh_s, a share per tick) and set 0.1 s on purpose: 6 ticks.
	["res://scenes/map/terrain/terrain_collision.gd", "refresh_s", 6],
	["res://scenes/map/nav/nav_service.gd", "rebake_swap_s", 180],
	["res://scenes/map/nav/nav_service.gd", "holes_rebake_s", 120],
	["res://scenes/ai/ai_roster.gd", "settle_s", 20],
	["res://scenes/ai/ai_clock.gd", "status_every_s", 12],
	["res://scenes/ai/ai_clock.gd", "stance_every_s", 60],
	["res://scenes/ai/ai_clock.gd", "perception_every_s", 6],
	["res://scenes/ai/ai_clock.gd", "groups_every_s", 6],
	["res://scenes/ai/ai_clock.gd", "replan_every_s", 60],
	["res://scenes/ai/ai_clock.gd", "think_every_s", 12],
	["res://data/match_rules.tres", "teleport_effect_s", 32],
	["res://data/match_rules.tres", "teleport_ring_s", 48],
]
## The AI's ages: [property in seconds, where it lives in the tactics, ages it had]. One age = 6 ticks (the perception job at Normal).
const AGES := [["rerate_s", "senses", 16], ["status_s", "senses", 8], ["souls_snapshot_s", "senses", 32], ["threat_s", "senses", 8],
	["wizard_replan_s", "wizard", 16], ["wizard_reissue_s", "wizard", 8]]


func run(_host: Node) -> Dictionary:
	return {"time_units_60hz": _at_60(), "time_units_30hz": _at_30(), "time_units_ai_ages": _ages()}


## Every value in seconds gives back, at 60 Hz, exactly the ticks it had.
func _at_60() -> Dictionary:
	var wrong := []
	for row in FIELDS:
		for value in _values(row[0], row[1]):
			if value == null:
				wrong.append("%s: no tiene %s" % [row[0].get_file(), row[1]])
			elif _flat(_ticks(value)) != _flat(row[2]):
				wrong.append("%s %s = %s → %s (era %s)" % [row[0].get_file(), row[1], value, _ticks(value), row[2]])
	var heal_exact: bool = RULES.guardian_heal_per_s == 1000.0 / 60.0
	return {"ok": wrong.is_empty() and heal_exact, "checked": FIELDS.size(), "wrong": wrong, "guardian_heal_exact": heal_exact}


## At 30 Hz the same seconds last the same real time, to within one tick.
func _at_30() -> Dictionary:
	var wrong := []
	var tps := MatchClock.TICKS_PER_SECOND
	MatchClock.TICKS_PER_SECOND = 30
	for row in FIELDS:
		for value in _values(row[0], row[1]):
			if value == null:
				continue
			var now: Array = _flat(_ticks(value))
			var was: Array = _flat(row[2])
			for i in was.size():
				if absf(float(now[i]) / 30.0 - float(was[i]) / 60.0) > 1.0 / 30.0 + 1e-9:
					wrong.append("%s %s: %d a 30 Hz, %d a 60 Hz" % [row[0].get_file(), row[1], now[i], was[i]])
	MatchClock.TICKS_PER_SECOND = tps
	return {"ok": wrong.is_empty() and MatchClock.TICKS_PER_SECOND == tps, "wrong": wrong}


## The tactics' seconds give their old ages, Easy keeps them (its slower clock stretches them), and at 30 Hz they last as long.
func _ages() -> Dictionary:
	var wrong := []
	var side: Node = SIDE.instantiate()
	var clock := side.get_node("Clock") as AiClock
	var normal := AiPlay.make(AiSeat.difficulty_of("normal"), null, clock.base_ticks(AiClock.Job.PERCEPTION))
	var easy := AiPlay.make(EASY, null, clock.base_ticks(AiClock.Job.PERCEPTION))
	for row: Array in AGES:
		var seconds := _seconds(normal.tactics, row)
		if normal.ages_for(seconds) != row[2] or easy.ages_for(seconds) != row[2]:
			wrong.append("%s → %d / Fácil %d (era %d)" % [row[0], normal.ages_for(seconds), easy.ages_for(seconds), row[2]])
	var tps := MatchClock.TICKS_PER_SECOND
	MatchClock.TICKS_PER_SECOND = 30
	var slow := AiPlay.make(normal.difficulty, null, clock.base_ticks(AiClock.Job.PERCEPTION))
	for row: Array in AGES:
		var ages := slow.ages_for(_seconds(normal.tactics, row))
		if absf(float(ages * slow.age_ticks) / 30.0 - float(int(row[2]) * 6) / 60.0) > float(slow.age_ticks) / 30.0 + 1e-9:
			wrong.append("%s a 30 Hz: %d edades de %d ticks" % [row[0], ages, slow.age_ticks])
	MatchClock.TICKS_PER_SECOND = tps
	side.free()
	return {"ok": wrong.is_empty() and normal.ages_for(normal.tactics.senses.rerate_s) == 16 and easy.age_ticks == 6, "wrong": wrong}


func _seconds(tactics: AiTactics, row: Array) -> float:
	var holder: Resource = tactics.senses if row[1] == "senses" else tactics
	return float(holder.get(row[0]))


func _ticks(value: Variant) -> Variant:
	if value is PackedFloat64Array or value is Array:
		var out := []
		for s in value:
			out.append(MatchClock.ticks_for(s))
		return out
	return MatchClock.ticks_for(float(value))


func _flat(value: Variant) -> Array:
	return value if value is Array else [value]


## The values of `property` in `where`: a script's default, every node of a scene that sets it, or a resource's own.
func _values(where: String, property: String) -> Array:
	if where.ends_with(".gd"):
		var script := load(where) as GDScript
		var value: Variant = script.get_property_default_value(property)
		if value == null:
			## A default that is not a constant (PackedFloat64Array([...])) is only known on an instance.
			var made: Object = script.new()
			value = made.get(property)
			if made is Node:
				made.free()
		return [value]
	if where.ends_with(".tres"):
		return [load(where).get(property)]
	var found := []
	var state := (load(where) as PackedScene).get_state()
	for node in state.get_node_count():
		for i in state.get_node_property_count(node):
			if state.get_node_property_name(node, i) == property:
				found.append(state.get_node_property_value(node, i))
	return found if not found.is_empty() else [null]
