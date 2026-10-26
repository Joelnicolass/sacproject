class_name DebugLog
extends RefCounted

## The one switch for the bench logs of the gameplay code (RFC-036 036b). Off in the product: nothing is on unless a
## bench scene calls enable()/enable_bench(), or the command line carries `--log=<cat>[,<cat>...]` (`--log=all` for
## every category). Gameplay asks `DebugLog.on(&"melee")` before printing; it never decides what to print.
##
## Categories (what the bench lines come from):
##   melee (MeleeWeapon), on_hit (MeleeOnHit), drain (LifeDrain), charge (LightningCharge),
##   shield (FireShield), shields (LifeShield), effects (AbilityEffect and friends), ability (AbilitySlot), eye (DivineSightEye),
##   touches (GrowingWave), flight (GroundHug), split (ShotSplit), strikes (ShotStrike), spikes (SpikeWave/SpikeImpact),
##   oil (Oiled and OilImpact), walk (Firewalking), vines (Vined), pull (Pulling), breath (BreathOfLife), quake (QuakeWave),
##   bolt (LightningStrike), halo (HaloOfEarth), devour (DevourGrowth), revive (FastRevive),
##   cling (Clinging, StickImpact), souls (Soul), hop (MiteHop), targets (TargetFutility), ai_seat (AiRoster «ia slot N lista», AiPerception «escaneo inicial»; the net runs pass --log=ai_seat), biome (MatchBiome: the god a match drew), ritual (Ritual and its parts: begin, complete, cancel).
## Off even in the bench (only `--log=`): ai_attack (AttackPhase: threat, enemy_ratio and the target of each replan, F371).
## ai_focus (FocusTask: each commitment with its kill seconds and score, F373). ai_order (AiCommandPort: every order the AI gives, with
## its ostate and goal; CreatureBrain: the wizard's trip to a mana source). gap (MeleeReach.close_in: one line per tick of every melee
## approach; agent/tools/melee_gap_expect.py reads it, so f177 and the spit flow pass --log=gap or enable it). pace (PaceFactors: a «ritmo»
## line on every tick a speed factor changes, so every tick of a Speedup that decays; f129, f130, f133 and f156_expect.py read it: --log=pace).
## terrain_load (TerrainShape and TerrainMesh: how long the ground's faces, index and mesh took to build; debug/terrain/load_time).

## Every category.
const BENCH: Array[StringName] = [
	&"melee", &"on_hit", &"drain", &"charge", &"shield", &"shields", &"effects", &"ability", &"touches",
	&"flight", &"split", &"strikes", &"spikes", &"oil", &"walk", &"vines", &"pull", &"breath", &"quake", &"bolt",
	&"halo", &"devour", &"revive", &"cling", &"souls", &"hop", &"targets", &"ritual", &"ai_seat",
]

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


## The categories the bench (debug/ai/ai_match.gd) always had on.
static func enable_bench() -> void:
	for category in BENCH:
		_on[category] = true


static func disable_all() -> void:
	_on.clear()
	_all = false
	_cli_read = true


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
