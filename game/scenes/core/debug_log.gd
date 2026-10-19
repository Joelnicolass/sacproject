class_name DebugLog
extends RefCounted

## The one switch for the bench logs of the gameplay code (RFC-036 036b). Off in the product: nothing is on unless a
## bench scene calls enable()/enable_bench(), or the command line carries `--log=<cat>[,<cat>...]` (`--log=all` for
## every category). Gameplay asks `DebugLog.on(&"melee")` before printing; it never decides what to print.
##
## Categories (what the bench lines come from):
##   gap/melee (MeleeAttack), on_hit (MeleeOnHit), drain (LifeDrain), charge (LightningCharge),
##   shield (FireShield), shields (LifeShield), effects (AbilityEffect and friends), ability (ActiveAbility), eye (DivineSightEye),
##   touches (GrowingWave), flight (GroundHug), split (ShotSplit), strikes (ShotStrike), spikes (SpikeWave/SpikeImpact),
##   oil (Oiled and OilImpact), walk (Firewalking), vines (Vined), pull (Pulling), breath (BreathOfLife), quake (QuakeWave),
##   bolt (LightningStrike), halo (HaloOfEarth), devour (DevourGrowth), pace (PaceFactors), revive (FastRevive),
##   cling (Clinging, StickImpact), souls (Soul), hop (MiteHop), targets (TargetFutility).
## Off even in the bench (only `--log=`): ai_attack (AttackPhase: threat, enemy_ratio and the target of each replan, F371).
## ai_focus (FocusTask: each commitment with its kill seconds and score, F373).

## Every category.
const BENCH: Array[StringName] = [
	&"gap", &"melee", &"on_hit", &"drain", &"charge", &"shield", &"shields", &"effects", &"ability", &"touches",
	&"flight", &"split", &"strikes", &"spikes", &"oil", &"walk", &"vines", &"pull", &"breath", &"quake", &"bolt",
	&"halo", &"devour", &"pace", &"revive", &"cling", &"souls", &"hop", &"targets",
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
