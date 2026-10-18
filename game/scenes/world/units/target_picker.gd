class_name TargetPicker
extends Node

## Chooses a creature's target by score (RFC-024 §1.2, 024b), as sacengine updateTarget (state.d:12924-12980)
## instead of "the closest". Child of unit.tscn; UnitBody.closest_foe delegates here when it exists, and
## without it the body keeps picking the closest.
##
## score(entry) = s*s  with  s = 1 - 0.75*d/ref        when d < ref
##                           s = 0.25*ref/d            when d >= ref            (targetScore, 12926-12929)
## a building keeps that score (12930); anything else is x1.25 (12931), x1.2 if it was the last to hit us
## (12932) and x1.3 if it is the current target (12933). The foe must be visible to the side
## (visibleFilter, 12936: SideVision) and score above `threshold` (0.25 patrol). The query radius is
## |center - body| + the distance where the best possible score (x1.25x1.2x1.3) falls to the threshold
## (12961-12963), not the sight range. Deviation from sacengine: with `within` (a guard or an escort) the
## candidates must also lie within that distance of the anchor, because patrolAround's threshold is ~0 at
## the anchor and would otherwise take any foe the side has seen at any range, making the unit leave and
## come back over and over. Missing («aprox.»): the DangerGrid factor (needs area spells to
## paint danger), the melee reach/height filter `maxTargetHeight` and the raging case. The scarab is a TargetPolicy (F136).
## Where the world has no SideVision (a bare body in a test), "visible" is "within its sight range".

signal picked(target: Node3D)

## The body that fights (a UnitBody).
@export var body: UnitBody
@export_group("Score (updateTarget)")
## 1 - near_slope * d/ref (state.d:12927).
@export var near_slope := 0.75
## far_factor * ref/d beyond ref (state.d:12927).
@export var far_factor := 0.25
## Not a building (state.d:12931).
@export var creature_weight := 1.25
## It hit us last (state.d:12932).
@export var last_attacker_weight := 1.2
## It is the current target (state.d:12933).
@export var current_weight := 1.3
## enum maxDist (state.d:12964).
@export var max_query_m := 5120.0
## Keep what each pick weighed in last_scores (probes and the debug scene). Off in a match.
@export var record_scores := false
## F136 (RFC-030h2): target rules by ranged attack (data/targeting/<tag>.tres). The one whose tag is the body's
## ranged attack picks and accepts in place of the enemy score; a body with none keeps this script's rules.
@export var policies: Array[TargetPolicy] = []

var last_attacker_id := 0
var _vision: SideVision
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
	_find_vision()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if body == null and not get_parent() is UnitBody:
		warnings.append("Falta el cuerpo (body).")
	return warnings


## targetScore (state.d:12925-12935) without the danger factor. Pure: the suite calls it.
static func score(distance: float, ref_range: float, building: bool, last_attacker: bool, current: bool, near_slope := 0.75, far_factor := 0.25, creature_weight := 1.25, last_attacker_weight := 1.2, current_weight := 1.3) -> float:
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


## scoreCutoff (state.d:12961-12963): the distance at which the best weight still reaches `threshold`.
static func score_cutoff(threshold: float, ref_range: float, max_weight := 1.25 * 1.2 * 1.3) -> float:
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
	var vision := _find_vision()
	var sight := body.type.sight_range if body.type else 0.0
	var best: Node3D = null
	var best_score := -1.0
	var best_distance := INF
	for group in body.target_groups:
		for node in get_tree().get_nodes_in_group(group):
			if not TargetRules.is_valid_foe_of(slot, node, body):
				continue
			var other := node as Node3D
			var from_body := _flat(here, other.global_position)
			if from_body > radius:
				continue
			if vision != null:
				if not vision.is_visible_to(slot, other):
					continue
			elif from_body > sight:
				continue
			var distance := _flat(center, other.global_position)
			if distance > within:
				continue
			var value := score(distance, ref_range, other.is_in_group("structure"), other.get_instance_id() == last_attacker_id, other == body.target, near_slope, far_factor, creature_weight, last_attacker_weight, current_weight)
			if value <= threshold:
				continue
			if record_scores:
				last_scores.append({"node": other, "score": value})
			if value > best_score or (value == best_score and distance < best_distance):
				best_score = value
				best_distance = distance
				best = other
	if record_scores:
		last_scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	total_us += Time.get_ticks_usec() - started
	if best != null:
		picked.emit(best)
	return best


## Whether the body may keep `node` as its target (UnitBody.accepts_target): the active policy's rule, or a foe
## (by stance unless `ordered`) as before policies.
func accepts(node: Variant, ordered: bool) -> bool:
	var policy := active()
	if policy != null:
		return policy.accepts(body, node, ordered)
	return TargetRules.is_valid_foe_of(body.owner_slot, node, body, not ordered)


## The policy for the body's ranged attack, or null (the default rules).
func active() -> TargetPolicy:
	if policies.is_empty() or body == null or body.type == null or body.type.ranged_attack_tag.is_empty():
		return null
	for policy in policies:
		if policy != null and policy.tag == body.type.ranged_attack_tag:
			return policy
	return null


## Something hit this body: it weighs x1.2 until the next hit (state.d:8905-8906, a creature only).
func note_attacker(attacker: Node3D) -> void:
	last_attacker_id = attacker.get_instance_id() if attacker != null else 0


## This body hit `foe`: the foe's side sees it. SideVision tells the victim's own picker (revealed).
func _on_struck(foe: Node3D, amount: float, _hit_chance: float, _roll: float) -> void:
	if amount <= 0.0 or foe == null or not is_instance_valid(foe):
		return
	var vision := _find_vision()
	if vision != null:
		vision.reveal(body, foe)


## Somebody hurt a body: when it is this one, remember who (x1.2 until the next hit).
func _on_revealed(attacker: Node3D, victim: Node3D) -> void:
	if victim == body:
		note_attacker(attacker)


func _find_vision() -> SideVision:
	if _vision == null or not is_instance_valid(_vision):
		_vision = get_tree().get_first_node_in_group(SideVision.GROUP) as SideVision
		if _vision != null and not _vision.revealed.is_connected(_on_revealed):
			_vision.revealed.connect(_on_revealed)
	return _vision


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
