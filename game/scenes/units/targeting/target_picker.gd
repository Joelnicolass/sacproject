class_name TargetPicker
extends Node

## Chooses a creature's target by score,
## instead of "the closest". Child of unit.tscn; UnitBody.closest_foe delegates here when it exists, and
## without it the body keeps picking the closest.
##
## score(entry) = s*s  with  s = 1 - 0.75*d/ref        when d < ref
##                           s = 0.25*ref/d            when d >= ref
## a building keeps that score; anything else is x1.25, x1.2 if it was the last to hit us
## and x1.3 if it is the current target. The foe must be visible to the side
## (VisionSides) and score above `threshold` (0.25 patrol). The query radius is
## |center - body| + the distance where the best possible score (x1.25x1.2x1.3) falls to the threshold,
## not the sight range. With `within` (a guard or an escort) the
## candidates must also lie within that distance of the anchor, because the guard threshold is ~0 at
## the anchor and would otherwise take any foe the side has seen at any range, making the unit leave and
## come back over and over. Missing («aprox.»): the DangerGrid factor (needs area spells to
## paint danger) and the raging case. A ranged attack with a target_policy (the Scarab's Healing web) picks and accepts in place of the score.
## A passive body (TargetRules.is_passive: aggressiveness 0 or a peasant) weighs `passive_weight` (as any
## foe, creatures stuck on villagers read as «they do not attack»); a melee-only walker skips flyers above its
## swing; a target TargetFutility banned is skipped.

signal picked(target: Node3D)

## The body that fights (a UnitBody).
@export var body: UnitBody
@export_group("Score")
## 1 - near_slope * d/ref.
@export var near_slope := 0.75
## far_factor * ref/d beyond ref.
@export var far_factor := 0.25
## Not a building.
@export var creature_weight := 1.25
## It hit us last.
@export var last_attacker_weight := 1.2
## It is the current target.
@export var current_weight := 1.3
## enum maxDist.
@export var max_query_m := 5120.0
## A passive body (aggressiveness 0) is worth this much. 1 = as any foe.
@export var passive_weight := 0.5
## A creature with no ranged attack that walks skips bodies whose feet are higher over the ground than
## the top of its swing (MeleeWeapon.height).
@export var melee_height_filter := true
## The futile targets of the body (optional: without it nothing is banned).
@export var futility: TargetFutility
## Keep what each pick weighed in last_scores (probes and the debug scene). Off in a match.
@export var record_scores := false
## Blind Rage: the rule of a body that is enraged, in place of everything above and of the ranged attack's
## target_policy (data/targeting/rage.tres).
@export var rage_policy: TargetPolicy

var last_attacker_id := 0
## What the last pick weighed, for probes and the report: [{node, score}] best first.
var last_scores: Array = []
var picks := 0
## Microseconds spent in pick(), for the report.
var total_us := 0


func _ready() -> void:
	if body == null:
		body = get_parent() as UnitBody
	if body != null and not body.struck.is_connected(_on_struck):
		body.struck.connect(_on_struck)
	if body != null and body.vision != null and not body.vision.hurt_by.is_connected(note_attacker):
		body.vision.hurt_by.connect(note_attacker)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null and not get_parent() is UnitBody:
		warnings.append("Missing the body (body).")
	return warnings


## The score without the danger factor. Pure: the suite calls it.
static func score(
	distance: float,
	ref_range: float,
	building: bool,
	last_attacker: bool,
	current: bool,
	near_slope := 0.75,
	far_factor := 0.25,
	creature_weight := 1.25,
	last_attacker_weight := 1.2,
	current_weight := 1.3
) -> float:
	var s := 0.0
	if distance < ref_range:
		s = 1.0 - near_slope * (distance / ref_range)
	else:
		s = far_factor * (ref_range / distance)
	s *= s
	if building:
		return s
	s *= creature_weight
	if last_attacker:
		s *= last_attacker_weight
	if current:
		s *= current_weight
	return s


## The distance at which the best weight still reaches `threshold`.
static func score_cutoff(
	threshold: float, ref_range: float, max_weight := 1.25 * 1.2 * 1.3
) -> float:
	var root := sqrt(maxf(threshold, 0.0) / max_weight)
	if root <= 0.0:
		return INF
	return ref_range * (1.0 - root) / 0.75 if 0.25 < root else 0.25 * ref_range / root


## The visible foe of the best score above `threshold` around `center` (null: none). `ref_range` is the
## distance where the score changes shape (100; 150 for advance). `within` limits the foes to that
## distance of `center` (a guard's sight range; INF for patrol and advance).
func pick(center: Vector3, threshold := 0.25, ref_range := 100.0, within := INF) -> Node3D:
	var policy := active()
	if policy != null:
		var chosen := policy.pick(body, center, within)
		if chosen != null:
			picked.emit(chosen)
		return chosen
	var started := Time.get_ticks_usec()
	picks += 1
	last_scores = []
	var slot := body.owner_slot
	var here := body.global_position
	var radius := minf(max_query_m, _flat(here, center) + score_cutoff(threshold, ref_range))
	var max_height := _max_target_height()
	var best: Node3D = null
	var best_score := -1.0
	var best_distance := INF
	for group in body.target_groups:
		for node in get_tree().get_nodes_in_group(group):
			if not TargetRules.is_valid_foe_of(slot, node, body):
				continue
			var other := node as Node3D
			if futility != null and futility.is_banned(other):
				continue
			if max_height < INF and _height_above_ground(other) > max_height:
				continue
			var from_body := _flat(here, other.global_position)
			if from_body > radius:
				continue
			if not VisionSides.sees(slot, other):
				continue
			var distance := _flat(center, other.global_position)
			if distance > within:
				continue
			var value := score(
				distance,
				ref_range,
				other.is_in_group(MapBuilding.STRUCTURE_GROUP),
				other.get_instance_id() == last_attacker_id,
				other == body.target,
				near_slope,
				far_factor,
				creature_weight,
				last_attacker_weight,
				current_weight
			)
			if TargetRules.is_passive(other):
				value *= passive_weight
			if value <= threshold:
				continue
			if record_scores:
				last_scores.append({"node": other, "score": value})
			if value > best_score or (value == best_score and distance < best_distance):
				best_score = value
				best_distance = distance
				best = other
	if record_scores:
		last_scores.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"])
		)
	total_us += Time.get_ticks_usec() - started
	if best != null:
		picked.emit(best)
	return best


## Whether the body may keep `node` as its target (UnitBody.accepts_target): the active policy's rule, or a foe
## (by stance unless `explicit`: the target of an explicit ATTACK order) as before policies.
func accepts(node: Variant, explicit: bool) -> bool:
	var policy := active()
	if policy != null:
		return policy.accepts(body, node, explicit)
	return TargetRules.is_valid_foe_of(body.owner_slot, node, body, not explicit)


## Whether the body's TargetFutility banned `node`.
func is_banned(node: Variant) -> bool:
	return futility != null and futility.is_banned(node)


## INF for a flyer or a body with a ranged attack, else the top of its swing.
func _max_target_height() -> float:
	if (
		not melee_height_filter
		or body.type == null
		or body.type.ranged_attack != null
		or body.is_flying()
	):
		return INF
	var melee := body.weapons.melee
	return melee.height if melee != null else INF


## How high the feet of `node` are over the ground (a flying creature; 0 for anything else).
static func _height_above_ground(node: Node3D) -> float:
	if not node is UnitBody or not (node as UnitBody).is_flying():
		return 0.0
	var unit := node as UnitBody
	return unit.global_position.y - unit.air.ground_height(unit.global_position)


## The rage policy while the body is enraged, else its ranged attack's target_policy, or null (the default rules).
func active() -> TargetPolicy:
	if rage_policy != null and body != null and body.afflictions.raging():
		return rage_policy
	if body == null or body.type == null or body.type.ranged_attack == null:
		return null
	return body.type.ranged_attack.target_policy


## Something hit this body: it weighs x1.2 until the next hit (a creature only).
func note_attacker(attacker: Node3D) -> void:
	last_attacker_id = attacker.get_instance_id() if attacker != null else 0


## This body hit `foe`: the foe's side sees it, and the foe remembers who (Vision.hurt_by reaches its own picker).
func _on_struck(foe: Node3D, amount: float, _hit_chance: float, _roll: float) -> void:
	if amount > 0.0 and foe != null and is_instance_valid(foe):
		VisionSides.reveal(body, foe)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
