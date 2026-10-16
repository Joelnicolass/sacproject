class_name GuardTask
extends AiTask

## GUARD (shiny.d:2195-2229 `replanGuard`, 2288-2336 `claimGuard`): the own wizard gets a record (his creatures escort him)
## and so does every own mana structure that is ready (its altar only while a ritual runs against it, with score 1.0). The score of a structure mixes the
## support of the other altars (probOr), the enemy's (probOr) and the influence of the enemy groups; the creatures
## that fit best (rateWithBase against the target) are claimed up to `score * souls` of worth. A guard creature gets an
## order to stay by the structure and fight what comes (t4oBrain cmd 1, shiny.d:2557-2570).
## Not ported: the guardian-bound creatures of the first pass (shiny.d:2292-2300).

func kind() -> Kind:
	return Kind.GUARD


func command() -> int:
	return 1


func replan() -> void:
	records.clear()
	var total := 0.0
	var profile := board.profile
	for target: AiTrack in board.perception.tracks_of(0):
		var score := 0.0
		if target.status & 0xc:
			## A body with status bits 4/8 (the wizard: 0x2000e): its creatures escort it (shiny.d:2200-2202).
			score = AiField.f32(target.value_6c() * profile.aggression * 0.6 + 0.4)
		else:
			if not (target.flags & AiTrack.STRUCTURE) or not (target.status & AiTrack.READY):
				continue
			if target.flags & AiTrack.ALTAR:
				## 0x48a94b: an altar under desecration scores 1.0; a quiet altar has no record.
				if not board.perception.desecration_against(target):
					continue
				score = 1.0
			else:
				var own_altars := board.distances_to(target, 0, AiTrack.ALTAR)
				var enemy_altars := board.distances_to(target, 3, AiTrack.ALTAR)
				var s := AiField.lerp_w(0.4, 0.5, AiField.prob_or(own_altars, 10.0, 3620.0))
				## thaum quirk (shiny.d:2211): the accumulator `total` is overwritten here, in the middle of the loop.
				total = AiField.lerp_w(s, 0.2, AiField.prob_or(enemy_altars, 10.0, 3620.0))
				score = AiField.lerp_w(s, 0.2, board.density(target.cur_pos, 10.0, 160.0))
		var record := board.new_record(target)
		var s3 := board.stance.influence(3, record.anchor, 10.0, 3620.0, record.target_acc)
		var fin := AiField.lerp_w(score, 0.6, s3)
		if fin == 0.0:
			continue
		record.score = fin
		AiRater.divide(record.target_acc, 0.0)
		insert_sorted(record)
		total += fin
	normalize(total)


func claim(free: Array[AiTrack]) -> float:
	var threshold := float(board.stance.recs[0].souls_a)
	var total := 0.0
	for record in records:
		var claimed_this := 0.0
		if total > threshold:
			continue
		## A body's value for this record does not change while the record claims (its place, its acc and the record's are fixed):
		## worked out once per record, then each claim takes the best of what is still free, in the order of `free` as before.
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


## The weight of `t` for `record` in claimGuard (shiny.d): rateWithBase against the target, by the square of the fall with distance
## (1 within 40 m, 0 at 3620 m); null when it cannot be claimed.
static func _claim_value(t: AiTrack, record: AiRecord) -> Variant:
	if t == record.target or not (t.status & 0x3):
		return null
	var d := t.extrap_pos.distance_to(record.anchor)
	var w := 0.0
	if d <= 40.0:
		w = 1.0
	elif d >= 3620.0:
		return null
	else:
		w = (3620.0 - d) * 0.0002793296007439494
		if w == 0.0:
			return null
	var w2 := w * w
	var value := AiRater.rate_with_base(t.acc, record.target_acc)
	if value <= 0.0:
		value = AiField.safediv(value, w2)
	else:
		value *= w2
	return value
