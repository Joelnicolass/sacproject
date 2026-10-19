class_name AiStance
extends Node

## The numbers that sum up the field (RFC-024 §3.1 `AiStance`; shiny.d:1220-1288 `updateStance`, 1061-1085 the
## threat of the wizard, 2064-2082 `influenceGroups`). For each category (0 own, 1 ally, 2 neutral, 3 enemy) it keeps
## a record: mana and max mana of its groups, the soul worth of its creatures, its Manaliths, the sum of group
## ratings and, against the enemy, the share of souls. Every 60 ticks (k1).
## Quirks of the original that matter and are kept: u[2], u[3], u[4] start at 1; the `u[6]` the divisor of acc1 and acc2 is
## the integer read of the float bits of the ratios (shiny.d:1284-1287, «thaum quirk»), so acc1 and acc2 are
## tiny numbers: summoning compares each creature with almost nothing.

class Rec extends RefCounted:
	var mana := 0
	var max_mana := 0
	var souls_a := 1
	var souls_b := 1
	var souls_all := 1
	var manaliths := 0
	## float words u[6], u[7], u[8] (ratio against the own record, k > 0; 1.0 for the own).
	var ratio_a := 1.0
	var ratio_b := 1.0
	var ratio_c := 1.0
	var acc := AiRater.new_acc()


@export var perception: AiPerception
@export var groups: AiGroups
@export var profile: AiProfile

var recs: Array[Rec] = [Rec.new(), Rec.new(), Rec.new(), Rec.new()]
var strength_ratio := 1.0
var acc1 := AiRater.new_acc()
var acc2 := AiRater.new_acc()
var enemy_wizards := 0


## updateStance (shiny.d:1220-1288).
func update() -> void:
	for k in 4:
		var rec := Rec.new()
		for group: AiGroup in groups.list(k):
			rec.mana += group.mana_sum
			rec.max_mana += group.max_mana_sum
			AiRater.combine(rec.acc, 1.0, group.acc, 1.0)
		for t: AiTrack in perception.bodies(k):
			var pair := AiGroups.souls_pair(t)
			rec.souls_a += pair.x
			rec.souls_b += pair.y
			rec.souls_all += pair.x + pair.y
		for t: AiTrack in perception.structures(k):
			if t.status & AiTrack.MANALITH:
				rec.manaliths += 1
		recs[k] = rec
	for k in range(1, 4):
		var rec := recs[k]
		var own := recs[0]
		rec.ratio_a = _ratio(own.souls_a, rec.souls_a + own.souls_a)
		rec.ratio_b = _ratio(own.souls_b, rec.souls_b + own.souls_b)
		rec.ratio_c = _ratio(own.souls_all, rec.souls_all + own.souls_all)
	enemy_wizards = 0
	for t: AiTrack in perception.bodies(3):
		if t.kind == AiTrack.Kind.WIZ:
			enemy_wizards += 1
	## strengthRatio (shiny.d:1268-1280).
	var ebx := 0
	var ebp := 0
	for t: AiTrack in perception.structures(3):
		if t.flags & AiTrack.ALTAR:
			ebx += 1
		if t.flags & AiTrack.SEEN:
			ebp += 1
	var edx := 0
	var edi := 0
	for t: AiTrack in perception.structures(2):
		if t.flags & AiTrack.CAPTURABLE:
			edx += 1
		if t.flags & AiTrack.SEEN:
			edi += 1
	strength_ratio = 1.0 if (edi + ebp == 0 and edx + ebx == 0) else AiField.f32(AiField.safediv(float(edi + ebp), float(edx + ebx)))
	acc1 = AiRater.new_acc()
	AiRater.combine(acc1, 1.0, recs[0].acc, 1.0)
	AiRater.combine(acc1, 1.0, recs[1].acc, 1.0)
	AiRater.divide(acc1, float(_bits(recs[1].ratio_a) + _bits(recs[0].ratio_a)))
	acc2 = AiRater.new_acc()
	AiRater.combine(acc2, 1.0, recs[3].acc, 1.0)
	AiRater.divide(acc2, float(_bits(recs[3].ratio_a)))


static func _ratio(num: int, den: int) -> float:
	return AiField.f32(AiField.safediv(float(num), float(den))) if den != 0 else 1.0


## `cast(int)` of the raw word of a float (shiny.d:171 `si`): the quirk of the divisor.
static func _bits(x: float) -> int:
	var raw := PackedFloat32Array([x]).to_byte_array()
	return raw.decode_s32(0)


## Souls ratio own/(own+enemy) the weights use: `sf(stanceRecs[3], 6)` (shiny.d:2955).
func enemy_ratio() -> float:
	return recs[3].ratio_a


## Manaliths of the side plus its allies' (retail `GetManaSource`: own+ally, shiny.d:2926 / 3128).
func manalith_count() -> int:
	return recs[0].manaliths + recs[1].manaliths


## influenceGroups (shiny.d:2064-2082): the groups of a category within `far` of `at`, weighted 1 up to `near` and
## linearly to 0 at `far`, are added into `acc` (combine with weight w). Returns the weighted souls divided by u[4].
func influence(category: int, at: Vector3, near: float, far: float, acc: PackedFloat32Array) -> float:
	var souls_w := 0.0
	for group: AiGroup in groups.list(category):
		if not (group.status_or & 1):
			continue
		var d := at.distance_to(group.center)
		var w := 0.0
		if d <= near:
			w = 1.0
		elif not (d < far):
			continue
		else:
			w = AiField.f32(AiField.safediv(far - d, far - near))
		if not acc.is_empty():
			AiRater.combine(acc, 1.0, group.acc, w)
		souls_w += w * float(group.souls_sum)
	return AiField.safediv(souls_w, float(recs[category].souls_all))


## RFC-053 053d (F373): the strength of the bodies of `category` within `radius` (flat) of `at`, as the side knows them: each body's
## rate (AiRater, the number the groups add) times the fraction of its health the side believes it has. Creatures only: the wizards
## fight with spells, and the rater weighs a wizard like eight Rangers (WIZARD_STATS), so with them in the sum the brawl of the
## creatures did not count (measured in f373: 4 Rangers and their wizard against a wizard and a Scarab, 1.12; without the AI's
## wizard, 0.43). The enemy wizard's danger is the side's threat (update_threat).
func local_strength(category: int, at: Vector3, radius: float) -> float:
	var sum := 0.0
	var radius_sq := radius * radius
	for t: AiTrack in perception.bodies(category):
		if t.kind == AiTrack.Kind.WIZ or not AiGroups.alive(t):
			continue
		var pos := perception.pos_of(t)
		var dx := pos.x - at.x
		var dz := pos.z - at.z
		if dx * dx + dz * dz > radius_sq:
			continue
		var health := perception.health_of(t)
		var fraction := clampf(float(health.x) / float(health.y), 0.0, 1.0) if health.y > 0 else 1.0
		sum += t.cached_rate * fraction
	return sum


## updateWiz (shiny.d:1061-1085): the threat of the wizard track, every 8 ticks of its age.
func update_threat(wizard: AiTrack) -> void:
	if wizard == null or not (wizard.flags & AiTrack.OWN) or wizard.age < wizard.threat_tick:
		return
	wizard.threat_tick = wizard.age + profile.threat_ticks
	wizard.threat = 0.0
	var acc0 := AiRater.new_acc()
	var acc1_local := AiRater.new_acc()
	var acc3 := AiRater.new_acc()
	influence(0, wizard.extrap_pos, profile.threat_near, profile.threat_far, acc0)
	influence(1, wizard.extrap_pos, profile.threat_near, profile.threat_far, acc1_local)
	influence(3, wizard.extrap_pos, profile.threat_near, profile.threat_far, acc3)
	wizard.threat = AiRater.rate(acc3)
	if wizard.threat != 0.0:
		wizard.threat = AiField.f32(AiField.safediv(wizard.threat, wizard.threat + AiRater.rate(acc0) + AiRater.rate(acc1_local)))
