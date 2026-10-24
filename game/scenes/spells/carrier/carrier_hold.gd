@tool
class_name CarrierHold
extends Node

## What a SpellCarrier does after arriving: it waits on its target (following it) for `hold_s`, says `settled` and stays `linger_s` more before it
## ends. Charm's spirits wait the spell's duration around the creature; Blind Rage's fist forms 82 ticks four metres over the land and comes down
## in the last half second; Intestinal Vaporization's guts turn around the target while it swells. It does not act on the target (TargetEffect does)
## and it does not draw. Server (or solo) only.
## Ref: sacengine updateCharm charming, updateBlindRage formingFist, updateIntestinalVaporization vaporizing (state.d:21447-21487, 21570-21615, 21992-22013).

@export var carrier: SpellCarrier
@export_range(0.0, 120.0, 0.01, "suffix:s") var hold_s := 0.0
## The wait is the spell's duration (SpellType.duration_s) in place of `hold_s`.
@export var hold_is_spell_duration := false
## Above 0: it rides this high over the land under the target (the fist); 0: at the target's center.
@export_range(0.0, 30.0, 0.1, "suffix:m") var ride_height_m := 0.0
## In the last `drop_s` of the wait it comes down from `ride_height_m` to the land.
@export_range(0.0, 10.0, 0.05, "suffix:s") var drop_s := 0.0
@export_range(0.0, 60.0, 0.01, "suffix:s") var linger_s := 0.0

var _target: Node3D
var _ticks := 0
var _total := 0
var _linger := 0


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if carrier != null else PackedStringArray(["Falta el SpellCarrier."])


func _ready() -> void:
	set_physics_process(false)


## Ticks the wait lasts for the carrier's spell.
func wait_ticks() -> int:
	var seconds := carrier.spell.duration_s if hold_is_spell_duration and carrier.spell != null else hold_s
	return MatchClock.ticks_for(seconds)


## Server or solo. The carrier arrived on `target` (null: a point): from now on it follows it.
func begin(target: Node3D) -> void:
	_target = target
	_total = wait_ticks()
	_ticks = 0
	_linger = MatchClock.ticks_for(linger_s)
	carrier.phase = SpellCarrier.Phase.HOLDING
	set_physics_process(true)
	if _total == 0:
		_settle()


func _physics_process(_delta: float) -> void:
	if carrier.phase == SpellCarrier.Phase.HOLDING:
		_ticks += 1
		_follow()
		if _ticks >= _total:
			_settle()
	elif carrier.phase == SpellCarrier.Phase.LINGERING:
		_linger -= 1
		if _linger <= 0:
			carrier.stop()


func _settle() -> void:
	carrier.settled.emit(_target if is_instance_valid(_target) else null)
	carrier.phase = SpellCarrier.Phase.LINGERING
	if _linger <= 0:
		carrier.stop()


## The carrier stays on the target: at its center, or `ride_height_m` over the land under it, coming down at the end.
func _follow() -> void:
	if not is_instance_valid(_target) or not _target.is_inside_tree():
		return
	var at := BodyNudge.center(_target)
	if ride_height_m > 0.0:
		var ground := GroundRay.surface_y(carrier, at, carrier.ground_mask, GroundRay.wizard_rids(get_tree()), at.y)
		var left := float(_total - _ticks) / MatchClock.TICKS_PER_SECOND_F
		var rise := 1.0 if drop_s <= 0.0 else clampf(left / drop_s, 0.0, 1.0)
		at = Vector3(at.x, ground + ride_height_m * rise, at.z)
	carrier.global_position = at
