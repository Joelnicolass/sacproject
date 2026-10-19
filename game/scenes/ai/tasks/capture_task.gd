class_name CaptureTask
extends AiTask

## CAPTURE (shiny.d:2118-2194 `replanCapture`, 2262-2286 `claimCapture`, retail 0x48dc04..0x48e21b): what the side wants to take.
## Three kinds of record, each with a score `lerp(s1, s2, s3)` (s1 the worth of the target, s2 the weight of the side's
## aggression, s3 = 1 - the influence of the enemy groups within 140 m):
##   - a free manafount (status UNBUILT): the wizard builds a Manalith over it (his cmd 2 block: castCachedInRange). Required
##     status 2. s1 = nodeValueScore(f1): the more fronts the enemy has taken (f1 = 1 - own Manaliths / free founts) the more it is worth.
##   - an enemy Manalith (or shrine): the creatures attack it. Only if the AI has territory there (territorialScore) or no Manalith of
##     its own. Required status 1. s1 = nodeValueScore(max(f1, f2)) * 0.99 * aggression.
##   - an enemy altar (flags 0x200): the profanation. Skipped without territory near it (a Manalith of the AI within 1000 m, an
##     altar within 50 m). With a Desecrate already underway against it the record is worth 0.4 (so the army keeps guarding); else
##     s1 = aggression² * 2 * (own share of souls - 0.3), required status 9 (a body that fights and a wizard). The wizard leads the
##     army and, once at the altar, Desecrates it (AiWizardBrain).
## Not ported: the record that hunts an enemy wizard (flags 0x10, status 8; shiny.d:2152-2157) and the first-pass guardian-bound
## creatures (guardian excluded here too, shiny.d:2272). The claim hands every free creature (status & 9) to the best record that
## the army can beat (rateWithBase >= 0), until the souls they hold pass `own souls * share * 0.9 * aggression`; with a Desecrate of the
## side underway it claims nothing, so the army stays where it is.

const TERRITORY_NEAR_M := 10.0
const TERRITORY_MANALITH_M := 1000.0
const TERRITORY_OTHER_M := 50.0


func kind() -> Kind:
	return Kind.CAPTURE


func command() -> int:
	return 2


func replan() -> void:
	records.clear()
	var stance := board.stance
	var perception := board.perception
	var aggression := board.profile.aggression
	## Own+ally Manaliths (retail), enemy ones, free founts.
	var a := stance.recs[0].manaliths + stance.recs[1].manaliths
	var b := stance.recs[3].manaliths
	var e := perception.neutral_founts
	var f1 := 0.0
	var f2 := 0.0
	if a != 0 and AiField.safediv(float(b + 1), float(a)) >= 1.0:
		f1 = 1.0
		f2 = AiField.safediv(float(b), float(e))
	elif e == 0:
		f1 = 1.0
		f2 = 0.0
	else:
		f1 = AiField.f32(1.0 - AiField.safediv(float(a), float(e)))
		f2 = AiField.f32(AiField.safediv(float(b), float(b + a)))
	for category in [2, 3]:
		for t: AiTrack in perception.structures(category):
			if not t.is_valid() or not (t.flags & AiTrack.CAPTURABLE):
				continue
			var required := 0
			var s1 := 0.0
			var s2 := 0.0
			if t.status & AiTrack.UNBUILT:
				required = 2
				s1 = node_value_score(f1, t)
				s2 = AiField.f32((1.0 - aggression) * 0.8 + 0.2)
			elif category == 3 and (t.flags & AiTrack.STRUCTURE) and ((t.status & AiTrack.MANALITH) or ((t.status & 0x40000) and not (t.flags & AiTrack.ALTAR))):
				if territorial_score(t.cur_pos, t) == 0.0 and a > 0:
					continue
				required = 1
				s1 = AiField.f32(AiField.f32(node_value_score(maxf(f2, f1), t) * 0.99) * aggression)
				s2 = AiField.f32((1.0 - aggression) * 0.9 + 0.1)
			elif t.flags & AiTrack.ALTAR:
				if territorial_score(t.cur_pos, t) == 0.0:
					continue
				if perception.desecration_against(t):
					required = 1
					s1 = 0.4
					s2 = AiField.f32(1.0 - aggression)
				else:
					var share := AiField.f32(2.0 * (stance.enemy_ratio() - 0.3))
					if share < 0.0:
						share = 0.0
					required = 9
					s2 = AiField.f32(maxf(1.0 - aggression, 0.4))
					s1 = AiField.f32(aggression * aggression * share)
			else:
				continue
			var record := board.new_record(t, 2)
			record.required_status = required
			AiRater.combine(record.target_acc, 1.0, t.acc, 1.0)
			var s3 := AiField.f32(1.0 - stance.influence(3, record.anchor, 10.0, 140.0, record.target_acc))
			var score := AiField.lerp_w(s1, s2, s3)
			if score == 0.0:
				continue
			record.score = score
			insert_sorted(record)
	## Decay the claimed scores by position (0.5^i) and normalize by the decayed sum (shiny.d:2188-2194).
	var factor := 1.0
	var total := 0.0
	for record in records:
		record.score = AiField.f32(record.score * factor)
		factor *= 0.5
		total += record.score
	normalize(AiField.f32(total))


## claimCapture (shiny.d:2262-2286).
func claim(free: Array[AiTrack]) -> float:
	var perception := board.perception
	if perception.own_desecration():
		return 0.0
	var stance := board.stance
	var threshold := AiField.f32(AiField.f32(float(stance.recs[0].souls_a) * stance.enemy_ratio() * 0.8999999761581421) * board.profile.aggression)
	var acc := AiRater.new_acc()
	var status_or := 0
	var count := 0
	for t in free:
		if t.is_guardian_bound():
			continue
		status_or |= t.status
		count += 1
		AiRater.combine(acc, float(count), t.acc, 1.0)
	var found: AiRecord
	for record in records:
		if (record.required_status & status_or) != record.required_status:
			continue
		if not (AiRater.rate_with_base(acc, record.target_acc) < 0.0):
			found = record
			break
	if found == null:
		return 0.0
	var total := 0.0
	for t in free.duplicate():
		if total > threshold:
			break
		if not t.is_guardian_bound() and (t.status & 9):
			total += board.claim_member(found, free, t)
	return total


## nodeValueScore (shiny.d:2083-2095): `f` pulled towards the density of the souls around (0.45), towards the shadow of the enemy
## altars over it (0.3) and the own ones (0.5). Retail weights; the beta uses 0.4 and 0.35.
func node_value_score(f: float, t: AiTrack) -> float:
	var r := AiField.lerp_w(f, 0.45, board.density(t.cur_pos, 10.0, 280.0))
	r = AiField.lerp_w(r, 0.3, AiField.prob_or(board.distances_to(t, 3, AiTrack.ALTAR), 10.0, 3620.0))
	r = AiField.lerp_w(r, 0.5, AiField.prob_or(board.distances_to(t, 0, AiTrack.ALTAR), 10.0, 3620.0))
	return r


## territorialScore (shiny.d:2023-2041, retail 0x488d70): how much of the AI's own ground (its structures and its allies') lies
## around `pos`: each one weighs 1 within 10 m, falling to 0 at 1000 m (a Manalith) or 50 m (any other), added as a probability.
func territorial_score(pos: Vector3, exclude: AiTrack) -> float:
	var acc := 0.0
	for category in [0, 1]:
		for t: AiTrack in board.perception.structures(category):
			if t == exclude:
				continue
			var reach := TERRITORY_MANALITH_M if (t.status & AiTrack.MANALITH) else TERRITORY_OTHER_M
			var d := AiField.f32(pos.distance_to(t.cur_pos))
			var s := 0.0
			if d <= TERRITORY_NEAR_M:
				s = 1.0
			elif d < reach:
				s = AiField.f32(AiField.safediv(reach - d, reach - TERRITORY_NEAR_M))
			acc = AiField.f32(s * s * (1.0 - acc) + acc)
	return acc
