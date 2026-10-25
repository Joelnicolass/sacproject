class_name AiKillEstimate
extends RefCounted

## RFC-053 053d (F373): how many seconds the side needs to kill a body, from what it knows (no cheat):
##   seconds = known health / (sum of the members' DPS - the healing it sees on the target).
## A member's DPS comes from its CreatureType (its ranged attack's damage over its cadence, or its melee blow over its swing), times the
## catalog resistance of the target's type (a shot's cadence: shot_period). The healing seen is the target's own regeneration (catalog) plus the most of: the enemy
## healers the side sees within HEAL_SEEN_M of the target (a creature that shoots its wounded, WoundedAllyPolicy) and the heal effect that
## shows on the target (HealEffect, the glow a human sees). The health is AiPerception.health_of: the last seen without perfect
## information. Static: FocusTask and AttackPhase call it, the suite tests the pure parts.

## Only healers this close to the target count (RFC-053 §9 053d).
const HEAL_SEEN_M := 30.0
## The shortest cadence a blow or a shot is taken to have (a type with no animation data).
const MIN_PERIOD_S := 0.5

## The targeting rules by ranged attack (TargetPicker.policies).
const POLICY_DIR := "res://data/targeting/"

## ability tag -> whether it is a healer's shot (shot_heals).
static var _heals_by_tag := {}


## Pure: seconds to take `health` with `dps` against `healing` per second; INF when the damage does not outrun the healing.
static func seconds(health: float, dps: float, healing: float) -> float:
	var net := dps - healing
	if health <= 0.0:
		return 0.0
	if net <= 0.0:
		return INF
	return health / net


## Pure: the damage per second a creature of `type` does to a body whose catalog data is `target_data` (CreatureType, WizardType or
## null: resistance 1). A healer's shot does none.
static func dps_of(type: CreatureType, target_data: Resource = null) -> float:
	if type == null:
		return 0.0
	if type.ranged_attack != null:
		var attack := type.ranged_attack
		if not shot_heals(attack.tag):
			return float(attack.damage) * _resistance(target_data, &"direct_ranged_resistance") / shot_period(type, attack)
	if type.melee_strength <= 0:
		return 0.0
	var swing := maxf(_mean_seconds(type.melee_animations), MIN_PERIOD_S)
	return float(type.melee_strength) * _resistance(target_data, &"melee_resistance") / swing


## Pure: the health per second a healer of `type` gives a body of `target_max` health (0: not a healer). The Healing web heals the
## patient's whole bar at HealEffect.HEAL_SPEED (heal_full) once per cadence of its shot.
static func heal_rate_of(type: CreatureType, target_max: float) -> float:
	if not is_healer(type) or target_max <= 0.0:
		return 0.0
	var attack := type.ranged_attack
	if attack == null:
		return 0.0
	return minf(HealEffect.HEAL_SPEED, target_max / shot_period(type, attack))


## Pure: seconds between two shots of a creature of `type` with `attack` (RangedAttack): it shoots with its first shoot clip, the
## cooldown starts at the clip's shoot tick, and the next shot starts once both the clip and the cooldown are over.
static func shot_period(type: CreatureType, attack: AbilityType) -> float:
	var length := 0.0
	var at := 0.0
	if not type.shoot_animations.is_empty():
		var clip: Dictionary = type.shoot_animations[0]
		var rate := float(clip.get("framerate", 30.0))
		if rate > 0.0 and int(clip.get("frames", 0)) > 1:
			length = float(clip.get("frames", 0.0)) / rate
			var ticks: Array = clip.get("shoot_ticks", [])
			at = float(ticks[0]) / rate if not ticks.is_empty() else length
	return maxf(maxf(length, at + attack.cooldown_s), MIN_PERIOD_S)


## Pure: a creature whose ranged shot heals its side.
static func is_healer(type: CreatureType) -> bool:
	return type != null and type.ranged_attack != null and shot_heals(type.ranged_attack.tag)


## Pure: whether the ranged attack `tag` is a healer's: its targeting rules (data/targeting/<tag>.tres, TargetPicker.policies) are a
## WoundedAllyPolicy, it shoots the wounded of its own side (the Scarab's Healing web). Read once per tag; the policy is already loaded
## with unit.tscn, so this never loads a shot's look and its FX from disk (that cost 22 ms on the first replan that met a Brainiac).
static func shot_heals(tag: String) -> bool:
	if tag.is_empty():
		return false
	if not _heals_by_tag.has(tag):
		var path := POLICY_DIR + tag + ".tres"
		_heals_by_tag[tag] = ResourceLoader.exists(path) and load(path) is WoundedAllyPolicy
	return bool(_heals_by_tag[tag])


## The catalog data of a body (CreatureType of a creature, WizardType of a wizard), null if none.
static func data_of(node: Node) -> Resource:
	if node == null or not is_instance_valid(node):
		return null
	var type: Variant = node.get("type") if "type" in node else null
	if type is CreatureType:
		return type
	if "wizard_type" in node:
		return node.get("wizard_type")
	return null


## The healing per second the side sees on `target` (see the header). `perception` is the side's.
static func seen_healing(perception: AiPerception, target: AiTrack) -> float:
	if target == null or not target.is_valid():
		return 0.0
	var data := data_of(target.node)
	var regen := float(data.get("regeneration_per_s")) if data != null else 0.0
	var at := perception.pos_of(target)
	var maximum := float(perception.health_of(target).y)
	var healers := 0.0
	var side: Array = perception.bodies(target.category())
	for other: AiTrack in side:
		if other == target:
			## A healer never picks itself, but its web bursts on its patient and heals all of its side within effect_range: it
			## heals itself while a wounded body of its side stands that close to it.
			if healer_near(perception, other, at) and _wounded_near(perception, other, side):
				healers += heal_rate_of(other.node.get("type") as CreatureType, maximum)
			continue
		if healer_near(perception, other, at):
			healers += heal_rate_of(other.node.get("type") as CreatureType, maximum)
	var glow := 0.0
	if perception.knows_live(target):
		var effect := target.node.get_node_or_null(HealEffect.NODE_NAME) as HealEffect
		if effect != null and effect.frames_left > 0:
			glow = effect.per_frame * HealEffect.FPS
	return regen + maxf(healers, glow)


## A body of `side` other than `healer`, not full by what the side knows, within the healer's web burst (effect_range).
static func _wounded_near(perception: AiPerception, healer: AiTrack, side: Array) -> bool:
	var attack := (healer.node.get("type") as CreatureType).ranged_attack
	var reach := attack.effect_range_m if attack != null else 0.0
	var at := perception.pos_of(healer)
	for other: AiTrack in side:
		if other == healer or not other.is_body() or not AiGroups.alive(other):
			continue
		var health := perception.health_of(other)
		if health.y > 0 and health.x < health.y and _flat(perception.pos_of(other), at) <= reach:
			return true
	return false


## `t` is a live healer the side sees within HEAL_SEEN_M of `at`.
static func healer_near(perception: AiPerception, t: AiTrack, at: Vector3) -> bool:
	if t == null or t.kind != AiTrack.Kind.CRE or not AiGroups.alive(t):
		return false
	## the cached catalog test first: the vision query is the costly one
	if not is_healer(t.node.get("type") as CreatureType) or not perception.knows_live(t):
		return false
	return _flat(perception.pos_of(t), at) <= HEAL_SEEN_M


## Seconds for `members` (own tracks) to kill `target`, from what `perception` knows.
static func kill_seconds(perception: AiPerception, target: AiTrack, members: Array[AiTrack]) -> float:
	var target_data := data_of(target.node)
	var dps := 0.0
	for m in members:
		dps += dps_of(m.node.get("type") as CreatureType, target_data)
	return seconds(float(perception.health_of(target).x), dps, seen_healing(perception, target))


static func _resistance(data: Resource, field: StringName) -> float:
	if data == null:
		return 1.0
	var value: Variant = data.get(field)
	return maxf(0.0, float(value)) if value != null else 1.0


## The mean length in seconds of a list of clips ({frames, framerate}).
static func _mean_seconds(clips: Array[Dictionary]) -> float:
	var total := 0.0
	var count := 0
	for clip in clips:
		var rate := float(clip.get("framerate", 0.0))
		if rate > 0.0:
			total += float(clip.get("frames", 0.0)) / rate
			count += 1
	return total / float(count) if count > 0 else 0.0


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
