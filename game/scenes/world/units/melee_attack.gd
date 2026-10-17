extends Node

## One melee swing at a time, timed by the creature's SXSK attack animation and resolved
## with sacengine `dealMeleeDamage` (state.d:9231-9263) plus the melee resistance of
## `dealDamage` (state.d:8948-8951). Runs on the server (or solo) only.
##
## Reach is sacengine `defaultMeleeHitbox` (sacobject.d:446-476): a box 1.3·size ahead of
## the body, size = (width + depth)/4, dimensions (width, depth, 1.5·height). The baked
## body gives width = depth = 2·reach. A swing starts when the target's box touches that
## melee box scaled by 0.8 (`attack`, state.d:12814); the hit lands only if it still
## touches the unscaled box on the attack tick.

signal struck(target: Node3D, amount: float, hit_chance: float, roll: float)

## sacengine `attack`: meleeHitboxFactor.
@export var start_factor := 0.8
## sacengine `defaultMeleeHitbox`: hitboxCenter *= 1.3 for most creatures.
@export var forward_factor := 1.3
@export var height_factor := 1.5
## sacengine `meleeAttackIsDownward`: target center this far below ours uses attack2.
@export var downward_threshold := 0.25
## sacengine `dealDamage`: melee damage *= 0.4 * meleeResistance.
@export var melee_resistance_scale := 0.4
## F117: the attacker's passiveOnDamage (Firefist ahtf) and its own health, which the factor reads. Optional: empty = ×1.
@export var passive: DamagePassive
@export var own_health: Health

## sacengine `defaultMeleeHitbox`: the Druid's box is 1.3× wider and deeper.
const WIDTH_SCALE := {"nmuh": 1.3}
## Used when the cache has no SXSK data: HUa1, the humanoid attack0 (24 frames, tick 15, 30 fps).
const FALLBACK_ANIMATION := {"tag": "HUa1", "frames": 24, "framerate": 30, "attack_ticks": [15]}

var type: CreatureType
var reach := 0.35
var height := 1.8

var _body: Node3D
var _rng: RandomNumberGenerator
var _target: Node3D
var _anim: Dictionary = {}
var _elapsed := 0.0
var _next_tick := 0


func setup(body: Node3D, creature: CreatureType, body_reach: float, body_height: float, rng: RandomNumberGenerator) -> void:
	_body = body
	type = creature
	reach = maxf(body_reach, 0.1)
	height = maxf(body_height, 0.6)
	## Never the global RNG: a body without a stream gets one derived from the match seed and its name.
	_rng = rng if rng else MatchSeed.rng(["melee", String(body.name)])


func is_swinging() -> bool:
	return not _anim.is_empty()


func cancel() -> void:
	_anim = {}
	_target = null


func can_start(target: Node3D) -> bool:
	return type != null and type.melee_strength > 0 and in_reach(target, start_factor)


## sacengine `startMeleeAttacking` (state.d:8725): attack2 when striking downward, else
## a random one of attack0/attack1.
func start(target: Node3D) -> void:
	_target = target
	_anim = _pick_animation(target)
	_elapsed = 0.0
	_next_tick = 0


## Advances the swing by delta. Returns false once the animation has ended.
func advance(delta: float) -> bool:
	if _anim.is_empty():
		return false
	_elapsed += delta
	var rate := float(_anim.get("framerate", 30))
	var ticks: Array = _anim.get("attack_ticks", [])
	var frames := int(_anim.get("frames", 1))
	## sacobject.d:420: an animation without attack events hits on its last frame.
	var tick_frames: Array = ticks if not ticks.is_empty() else [frames - 1]
	while _next_tick < tick_frames.size() and _elapsed >= float(tick_frames[_next_tick]) / rate:
		_next_tick += 1
		_land()
	if _elapsed >= float(frames) / rate:
		_anim = {}
		return false
	return true


func swing_period_s(index: int) -> float:
	var anim := _animation(index)
	return float(anim.get("frames", 0)) / float(anim.get("framerate", 30)) if not anim.is_empty() else 0.0


func in_reach(target: Node3D, factor: float) -> bool:
	if _body == null or target == null or not is_instance_valid(target):
		return false
	var widen := float(WIDTH_SCALE.get(type.tag if type else "", 1.0))
	var center := _body.global_position + facing_of(_body) * (forward_factor * reach)
	var half := reach * widen * factor
	var foe := profile_of(target)
	var foe_reach := float(foe.get("reach", 0.35))
	var at := target.global_position
	if absf(at.x - center.x) > half + foe_reach or absf(at.z - center.z) > half + foe_reach:
		return false
	var box_mid := _body.global_position.y + height * 0.5
	var box_half := height * height_factor * 0.5 * factor
	return at.y <= box_mid + box_half and at.y + float(foe.get("height", 1.8)) >= box_mid - box_half


## sacengine dealMeleeDamage (state.d:9231-9244), then the melee resistance of
## dealDamage (state.d:8951). Effects (slime, lightning charge, shields) are not in this cut.
func roll_damage(target: Node3D, anim: Dictionary) -> Dictionary:
	var ticks: Array = anim.get("attack_ticks", [])
	var pending := float(anim.get("frames", 1)) / (float(anim.get("framerate", 30)) * float(maxi(1, ticks.size())))
	var facing := 1.5 + 0.5 * facing_of(_body).dot(facing_of(target))
	var damage := facing * pending
	var foe := profile_of(target)
	var accuracy := float(type.melee_accuracy)
	var total := accuracy + float(foe.get("evasion", 0.0)) / facing
	if not (total > 0.0):
		return {"amount": 0.0, "chance": 0.0, "roll": 1.0}
	var hit_chance := accuracy / total
	var roll := _rng.randf()
	if roll >= hit_chance:
		damage *= (1.0 - roll) / (1.0 - hit_chance)
	damage *= float(type.melee_strength)
	## F122: the poison's resistanceBonus goes inside the max (state.d:8950-8951); Poisoning owns it.
	damage *= melee_resistance_scale * maxf(0.0, float(foe.get("resistance", 1.0)) + Poisoning.resistance_bonus_of(target))
	return {"amount": damage, "chance": hit_chance, "roll": roll}


static func facing_of(node: Node3D) -> Vector3:
	if node.has_method("facing_flat"):
		return node.call("facing_flat")
	var ahead := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, node.global_rotation.y)
	return Vector3(ahead.x, 0.0, ahead.z).normalized()


## Defense and size of any target: a UnitBody answers melee_profile(); a wizard reads WIZD.
static func profile_of(target: Node3D) -> Dictionary:
	if target.has_method("melee_profile"):
		return target.call("melee_profile")
	var model := str(target.get("model")) if "model" in target else ""
	var info := BodyLibrary.info(model)
	var result := {
		"evasion": 0.0,
		"resistance": 1.0,
		"reach": float(info.get("reach", 0.35)),
		"height": float(info.get("height", 1.8)),
	}
	var wizard: WizardType = GameData.wizard(str(target.get("wizard_tag"))) if "wizard_tag" in target else null
	if wizard:
		result["evasion"] = float(wizard.melee_evasion)
		result["resistance"] = wizard.melee_resistance
	return result


func _land() -> void:
	var target := _target
	if target == null or not is_instance_valid(target) or not in_reach(target, 1.0):
		return
	var health := target.get_node_or_null("Health")
	if health == null or health.call("is_dead"):
		return
	var result := roll_damage(target, _anim)
	## dealDamage scales melee by rockForm and the other shields too (state.d:8962-8969).
	var amount := float(result["amount"]) * maxf(0.0, float(health.get("damage_factor"))) * _attack_factor()
	if amount <= 0.0:
		return
	health.call("damage", amount, int(_body.get("owner_slot")))
	struck.emit(target, amount, float(result["chance"]), float(result["roll"]))


func _pick_animation(target: Node3D) -> Dictionary:
	var own_mid := _body.global_position.y + height * 0.5
	var foe_mid := target.global_position.y + float(profile_of(target).get("height", 1.8)) * 0.5
	if foe_mid + downward_threshold < own_mid and not _animation(2).is_empty():
		return _animation(2)
	var choices: Array[Dictionary] = []
	for index in 2:
		if not _animation(index).is_empty():
			choices.append(_animation(index))
	if choices.is_empty():
		return FALLBACK_ANIMATION
	return choices[_rng.randi() % choices.size()]


func _animation(index: int) -> Dictionary:
	if type == null or index >= type.melee_animations.size():
		return {}
	var anim: Dictionary = type.melee_animations[index]
	return anim if int(anim.get("frames", 0)) > 0 else {}


## sacengine attackDamageFactor (state.d:8882-8892): a guardian hits harder (1 for a body without the property), and the
## passive scales melee by the attacker's health (Firefist).
func _attack_factor() -> float:
	var factor: Variant = _body.get("attack_factor")
	var result := maxf(0.0, float(factor)) if factor != null else 1.0
	if passive != null and own_health != null and own_health.maximum > 0.0:
		result *= passive.outgoing_melee_factor(own_health.current / own_health.maximum)
	return result
