class_name GuardTask
extends AiTask

## What the side guards: the own wizard gets a record (his creatures escort him) and so does every
## own mana structure that is ready (its altar only while a ritual runs against it, with score 1.0).
## The score of a structure mixes the support of the other altars, the enemy's and
## the influence of the enemy groups; the creatures that fit best (AiRater.rate_with_base against the target)
## are claimed up to `score * souls` of worth. A guard creature gets an order to stay by the
## structure and fight what comes. Not ported: the guardian-bound creatures of the first pass.

## The claim's fall with distance: 1 within CLAIM_NEAR_M, 0 at CLAIM_FAR_M; the scale is
## 1 / (far - near) as the original's float32.
const CLAIM_NEAR_M := 40.0
const CLAIM_FAR_M := 3620.0
const CLAIM_SCALE := 0.0002793296007439494


func kind() -> Kind:
	return Kind.GUARD


func replan() -> void:
	records.clear()
	var total := 0.0
	var aggression := board.play.aggression
	for target: AiTrack in board.perception.tracks_of(AiTrack.Relation.OWN):
		var score := 0.0
		if target.is_wizard():
			# The wizard: its creatures escort it.
			score = AiField.f32(target.value_6c() * aggression * 0.6 + 0.4)
		else:
			if target.kind != AiTrack.Kind.STRUCTURE or not target.ready:
				continue
			if target.is_altar():
				# An altar under desecration scores 1.0; a quiet altar has no record.
				if not board.perception.desecration_against(target):
					continue
				score = 1.0
			else:
				var own_altars := board.distances_to_altars(target, AiTrack.Relation.OWN)
				var enemy_altars := board.distances_to_altars(target, AiTrack.Relation.ENEMY)
				var s := AiField.lerp_w(0.4, 0.5, AiField.prob_or(own_altars, 10.0, 3620.0))
				# Quirk of the original: the accumulator `total` is overwritten here, in the middle of the
				# loop.
				total = AiField.lerp_w(s, 0.2, AiField.prob_or(enemy_altars, 10.0, 3620.0))
				score = AiField.lerp_w(s, 0.2, board.density(target.cur_pos, 10.0, 160.0))
		var record := board.new_record(target)
		var s3 := board.stance.influence(
			AiTrack.Relation.ENEMY, record.anchor, 10.0, 3620.0, record.target_acc
		)
		var fin := AiField.lerp_w(score, 0.6, s3)
		if fin == 0.0:
			continue
		record.score = fin
		AiRater.divide(record.target_acc, 0.0)
		insert_sorted(record)
		total += fin
	normalize(total)


func claim(free: Array[AiTrack]) -> float:
	var threshold := float(board.stance.recs[AiTrack.Relation.OWN].souls_a)
	var total := 0.0
	for record in records:
		var claimed_this := 0.0
		if total > threshold:
			continue
		# A body's value for this record does not change while the record claims (its place, its acc
		# and the record's are fixed): worked out once per record, then each claim takes the best of
		# what is still free, in the order of `free`.
		var values := {}
		for t in free:
			var value: Variant = _claim_value(t, record)
			if value != null:
				values[t] = value
		while claimed_this + 0.5 <= record.score * threshold:
			var best: AiTrack = null
			var best_value := 0.0
			for t in free:
				if not values.has(t):
					continue
				var value: float = values[t]
				if best == null or best_value < value:
					best_value = value
					best = t
			if best == null:
				break
			claimed_this += board.claim_member(record, free, best)
		total += claimed_this
	return total


## The weight of `t` for `record` in the claim: AiRater.rate_with_base against the target, by the square of
## the fall with distance (1 within CLAIM_NEAR_M, 0 at CLAIM_FAR_M); null when it cannot be claimed.
static func _claim_value(t: AiTrack, record: AiRecord) -> Variant:
	if t == record.target or not t.fights:
		return null
	var d := t.extrap_pos.distance_to(record.anchor)
	var w := 0.0
	if d <= CLAIM_NEAR_M:
		w = 1.0
	elif d >= CLAIM_FAR_M:
		return null
	else:
		w = (CLAIM_FAR_M - d) * CLAIM_SCALE
		if w == 0.0:
			return null
	var w2 := w * w
	var value := AiRater.rate_with_base(t.acc, record.target_acc)
	if value <= 0.0:
		value = AiField.safediv(value, w2)
	else:
		value *= w2
	return value
