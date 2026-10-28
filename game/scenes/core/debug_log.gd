class_name DebugLog
extends RefCounted

## The one switch for the check logs of the gameplay code. Off in the product: nothing is on unless a
## scene calls enable(), or the command line carries `--log=<cat>[,<cat>...]` (`--log=all` for
## every category). Gameplay asks `DebugLog.on(&"melee")` before printing; it never decides what to print.
##
## Categories (what the check lines come from):
##   melee (MeleeWeapon), on_hit (MeleeOnHit), drain (LifeDrain), charge (LightningCharge),
##   shield (FireShield), shields (LifeShield), effects (AbilityEffect and friends), ability (AbilitySlot), eye (DivineSightEye),
##   touches (GrowingWave), flight (GroundHugFlight), split (SplitFlight), strikes (ShotStrike), spikes (SpikeWave/SpikeImpact),
##   oil (Oiled and OilImpact), walk (Firewalking), vines (Vined), pull (Pulling), breath (BreathOfLife), quake (QuakeWave),
##   bolt (LightningStrike), halo (HaloOfEarth), devour (DevourGrowth), revive (FastRevive),
##   cling (Clinging, StickImpact), souls (Soul), hop (MiteHop), targets (TargetFutility), ai_seat (AiRoster «ai slot N ready», AiPerception «first scan»; the net runs pass --log=ai_seat), biome (MatchBiome: the god a match drew), atmosphere (MatchBiome «atmosphere seed», Atmosphere: hour and weather every 10 s), life (AmbientLifeLayer «vida spots activos a/n» every 10 s), ritual (Ritual and its parts: begin, complete, cancel).
## More categories: ai_attack (AttackPhase: threat, enemy_ratio and the target of each replan).
## ai_focus (FocusTask: each commitment with its kill seconds and score). ai_order (AiCommandPort: every order the AI gives, with
## its ostate and goal; CreatureBrain: the wizard's trip to a mana source). gap (MeleeReach.close_in: one line per tick of every melee
## approach: --log=gap). pace (PaceFactors: a «ritmo» line on every tick a speed factor changes, so every tick of a Speedup that
## decays: --log=pace). terrain_load (TerrainShape and TerrainMesh: how long the ground's faces, index and mesh took to build).
## nav (NavService, MapNavRegion: the navmesh in play and each re-bake by zones; NavMeshBackend: the map that never synced).
## orders (Orders: «order <command> <n>» for every human order; the AI's too with Orders.log_ai_orders).
## scars (GroundScars: every request to paint a mark on the ground, painted or refused and why).

static var _on: Dictionary = {}
static var _all := false
static var _cli_read := false


## Whether the category prints. The first call reads `--log=` from the user arguments (after `--`).
static func on(category: StringName) -> bool:
	if not _cli_read:
		_read_cli()
	return _all or _on.has(category)


static func enable(category: StringName) -> void:
	_on[category] = true


static func _read_cli() -> void:
	_cli_read = true
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--log="):
			continue
		for category in arg.substr(6).split(",", false):
			if category == "all":
				_all = true
			else:
				_on[StringName(category)] = true
