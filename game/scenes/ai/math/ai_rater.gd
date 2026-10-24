class_name AiRater
extends RefCounted

## The rater of the original AI (RFC-024 §3.1 `AiRater`): how much a creature, a wizard or a group is worth,
## in five numbers: [0] melee, [1] abilities, [2] health against melee, [3] health against ranged, [4] speed.
## It is a port of shiny.d:109-130 (accumulator), 199-263 (rater1 formulas) and 207-229 (combine, divide, rate,
## rateWithBase). The engine uses double arithmetic and stores floats: every accumulator is a
## PackedFloat32Array (so every store is a float32) and the intermediate sums stay double.
## The numbers are the CRE8 words of the file (the scale `typeStats`, shiny.d:230-241, reads): see stats_of().

const RATE_MELEE := 0
const RATE_ABILITY := 1
const RATE_HEALTH_MELEE := 2
const RATE_HEALTH_RANGED := 3
const RATE_SPEED := 4

## shiny.d:197-199: 0x4bb7a0, 1/980 (0x4bcde0), 0.04 (0x4bcdd8).
const MILLI := 0.001
const INV_FLY := 1.0 / 980.0
const ABILITY_K := 0.04

## thaum's wizd loader forces these over the file values (shiny.d:235): the rater sees every wizard like this.
## [meleeAccuracy, meleeEvasion, run, fly, health, regen, drain, rangedAcc, meleeRes, directRangedRes, meleeStrength, mana]
const WIZARD_STATS := {
	"melee_accuracy": 1250, "melee_evasion": 1250, "run": 1000, "fly": 0, "health": 1500, "regen": 1000,
	"drain": 0, "ranged_accuracy": 0, "melee_res": 1000, "ranged_res": 1000, "melee_strength": 120, "mana": 1000,
}


static func new_acc() -> PackedFloat32Array:
	var acc := PackedFloat32Array()
	acc.resize(5)
	return acc


## MSVCRT _ftol (shiny.d:20-26): round to nearest, ties to even.
static func ftol(x: float) -> int:
	var f := floorf(x)
	var d := x - f
	var i := int(f)
	if d > 0.5:
		i += 1
	elif d == 0.5:
		i += i & 1
	return i


## The words of the CRE8 the rater reads, in the file's scale (what export_stats.py divided): speeds x100 (u16 /100),
## regeneration x60 (per second to per frame... the file word), drain x1000, resistances x1000.
static func stats_of(type: CreatureType) -> Dictionary:
	return {
		"melee_accuracy": type.melee_accuracy, "melee_evasion": type.melee_evasion,
		"run": ftol(type.running_speed * 100.0), "fly": ftol(type.flying_speed * 100.0),
		"health": type.health, "regen": ftol(type.regeneration_per_s * 60.0), "drain": ftol(type.drain * 1000.0),
		"ranged_accuracy": type.ranged_accuracy,
		"melee_res": ftol(type.melee_resistance * 1000.0), "ranged_res": ftol(type.direct_ranged_resistance * 1000.0),
		"melee_strength": type.melee_strength, "mana": type.mana,
	}


## shiny.d:251-262 `fillStats`: ratings 0, 2, 3 and 4.
static func fill_stats(acc: PackedFloat32Array, ts: Dictionary) -> void:
	acc[RATE_MELEE] = float(ts["melee_strength"]) * (float(ts["melee_accuracy"]) * MILLI)
	var unk11k := AiField.f32(float(ts["melee_evasion"]) * MILLI)
	var p1 := unk11k * float(ts["health"]) * ((float(ts["regen"]) + 2.0 * float(ts["drain"])) * MILLI)
	var p1f := AiField.f32(p1)
	var melee_res := 1.0 if int(ts["melee_res"]) == 0 else float(ts["melee_res"])
	var r2 := AiField.safediv(1000.0, melee_res) * p1f
	if int(ts["fly"]) > 0:
		r2 *= 4.0
	acc[RATE_HEALTH_MELEE] = r2
	var ranged_res := 1.0 if int(ts["ranged_res"]) == 0 else float(ts["ranged_res"])
	acc[RATE_HEALTH_RANGED] = AiField.safediv(1000.0, ranged_res) * p1f
	var run_f := float(ts["run"])
	var fly_f := float(ts["fly"])
	acc[RATE_SPEED] = (fly_f if run_f < fly_f else run_f) * MILLI


## shiny.d:243-249 `abilityAcc`: an ability adds unk10*0.001*amount2 * (rangedAcc*k*range * (1 - f)) * 0.04, with
## f = cost/mana when the mana is above the cost and 1 otherwise; k = 0.001, or 1/980 for a flier.
static func ability_acc(acc: PackedFloat32Array, amount2: float, range_m: float, mana_cost: float, unk10: float, ranged_accuracy: float, mana: float, fly: float) -> void:
	var t1 := unk10 * MILLI * amount2
	var k := ranged_accuracy * (INV_FLY if fly != 0.0 else MILLI) * range_m
	var f := AiField.safediv(mana_cost, mana) if mana > mana_cost else 1.0
	acc[RATE_ABILITY] = acc[RATE_ABILITY] + t1 * (k * (1.0 - f)) * ABILITY_K


## shiny.d:265-281 `fillByTag` (the worth of a creature a wizard may summon): the stats, then every ability of the
## CRE8 with the type's own mana. `abilities` are AbilityType (amount2, range, mana_cost). Port limit: export_stats.py
## keeps 3 of the 8 ability slots of the CRE8 (92, 96, 124).
static func fill_by_tag(type: CreatureType, abilities: Array) -> PackedFloat32Array:
	var acc := new_acc()
	var ts := stats_of(type)
	fill_stats(acc, ts)
	acc[RATE_ABILITY] = 0.0
	for ability: AbilityType in abilities:
		if ability != null:
			ability_acc(acc, float(ability.amount2), ability.cast_range_m, float(ability.mana_cost), float(ts["melee_accuracy"]), float(ts["ranged_accuracy"]), float(ts["mana"]), float(ts["fly"]))
	return acc


## shiny.d:283-306 `fillFromObject` (the worth of a body on the field, with its mana now): creatures use their abilities
## that are attacks on creatures (flags1 & 0x4000 and flags & targetCreatures); a wizard adds its book (spells with
## flags1 & 0xfc00: amount2*range*(1-f)*0.04). `ts` from stats_of() or WIZARD_STATS.
static func fill_from_object(ts: Dictionary, current_mana: int, abilities: Array, spells: Array) -> PackedFloat32Array:
	var acc := new_acc()
	fill_stats(acc, ts)
	acc[RATE_ABILITY] = 0.0
	var mana_f := float(current_mana)
	for ability: AbilityType in abilities:
		if ability == null or (ability.flags1 & 0x4000) == 0 or (ability.flags & 4) == 0:
			continue
		ability_acc(acc, float(ability.amount2), ability.cast_range_m, float(ability.mana_cost), float(ts["melee_accuracy"]), float(ts["ranged_accuracy"]), mana_f, float(ts["fly"]))
	for spell: SpellType in spells:
		if spell == null or (spell.flags1 & 0xfc00) == 0:
			continue
		var t := float(spell.amount2) * spell.cast_range_m
		var f := AiField.safediv(float(spell.mana_cost), mana_f) if mana_f > float(spell.mana_cost) else 1.0
		t *= (1.0 - f)
		t *= ABILITY_K
		acc[RATE_ABILITY] = acc[RATE_ABILITY] + t
	return acc


## shiny.d:207-209 `combine` (0x4891e0): a = wB*b + wA*a, the five elements.
static func combine(a: PackedFloat32Array, w_a: float, b: PackedFloat32Array, w_b: float) -> void:
	for i in 5:
		a[i] = float(w_b) * float(b[i]) + float(w_a) * float(a[i])


## shiny.d:210-213 `divide`: elements 0..3 only; w = 0 does nothing.
static func divide(acc: PackedFloat32Array, w: float) -> void:
	if w == 0.0:
		return
	for i in 4:
		acc[i] = AiField.safediv(acc[i], w)


## shiny.d:214-220 `rate` (0x488a60): ((r3 + r2) * 0.5) + 2*(r1 + r0). The caller keeps the answer as the cached rate.
static func rate(acc: PackedFloat32Array) -> float:
	var r := (float(acc[3]) + acc[2]) * 0.5
	var s := float(acc[1]) + acc[0]
	r += s + s
	return AiField.f32(r)


static func _pos(x: float) -> float:
	return x if x > 0.0 else 0.0


## shiny.d:221-229 `rateWithBase` (0x4889e0): what `a` is worth against `b`.
static func rate_with_base(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var r := _pos(float(a[0]) - 0.1 * b[2]) + _pos(float(a[1]) - 0.1 * b[3])
	var t := _pos(float(b[1]) - 0.1 * a[3]) + _pos(float(b[0]) - 0.1 * a[2])
	r = r - t + AiField.f32(a[4] - b[4]) * 10.0
	return AiField.f32(r)
