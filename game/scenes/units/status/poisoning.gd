class_name Poisoning
extends Node

## F122 (RFC-030k-a): the one owner of the poison on a body (creature or wizard). Its children are the doses (Poisoned);
## it runs them once per physics tick in the order they came, frees the ones that end, and is the only one that answers
## what they add up to (sacengine Effects, stats.d:50-55):
##   resistance_bonus()     1e-3 · Σ ires, added inside max(0, resistance + bonus) for every kind of damage (state.d:8950-8957)
##   regeneration_factor()  Π freg of the live doses (poison(), 11604; restorePoisonRegeneration, 26103-26112)
##   mana_blocked()         a dose past its 2 s blocks giveMana (state.d:8829, 23556-23558)
##   damage_sum()           Σ int(per second) (poisonDamage, what an infection passes on)
## Health, ManaPool and MeleeWeapon ask it, never a dose. Server (or solo) only: on a client it does nothing.
##
## Infection (updatePoison, state.d:23537-23552): every tick, each infectious dose touches every live creature and wizard
## whose box meets the body's box grown `infection_margin_m`, of any side, the body excepted. One with no infection
## cooldown gets a dose of damage_sum() per second for the frames this dose has left, infectious, with its debuffs, its kind
## and its attacker, and keeps an infection cooldown of those frames + `infection_cooldown_extra_s` (ticks of
## MatchClock). The body that infected it has no cooldown of its own, so the first victim is infected back once.
## Divergence (declared): checked on every tick, without sacengine's AI-queue gate.

## The body the doses act on (its Health, its box). Empty = the parent.
@export var body: Node3D
@export var health: Health
## How long a dose blocks the body's mana.
## Ref: sacengine Poison.manaBlockDelay = 2·updateFPS.
@export_range(0.0, 60.0, 0.0001, "suffix:s") var mana_block_s := 2.0
## sacengine updatePoison: hitbox[0] -= 2, hitbox[1] += 2.
@export var infection_margin_m := 2.0
## A body just infected cannot be infected again for the dose's life plus this.
## Ref: sacengine infectionCooldown = lifetime + 3·updateFPS.
@export_range(0.0, 60.0, 0.0001, "suffix:s") var infection_cooldown_extra_s := 3.0
## sacengine movingObjects: who an infection may touch.
@export var groups: Array[StringName] = [&"wizard", &"unit"]
@export_group("Look")
## The puff on the body while a dose takes health, and its socket (relativePoison, state.d:23565-23575: one particle every 2
## frames inside the box; a puff every 30 ticks is the same rate). Empty = none.
@export var dose_fx: ParticleType = preload("res://data/fx/poison_dose.tres")
@export var dose_socket: BodyFacts.Socket = BodyFacts.Socket.CENTER
@export_range(0.0, 5.0, 0.0001, "suffix:s") var fx_every_s := 0.5

## MatchClock tick until which no infection reaches this body.
var _infection_until := 0
var _blocked := false


## The Poisoning of `node`, or null (a body without one is never poisoned).
static func of(node: Node) -> Poisoning:
	return (node.get_node_or_null("Poisoning") as Poisoning) if node else null


## The poison's resistance bonus of `node` (0 without Poisoning). For callers that apply the resistance themselves (melee).
static func resistance_bonus_of(node: Node) -> float:
	var poisoning := of(node)
	return poisoning.resistance_bonus() if poisoning else 0.0


## One dose on `target` through its Poisoning; null (and a line in the log) when it has none.
static func dose_body(target: Node, per_second: float, lifetime: int, kind: StringName, from_slot: int, infectious := false,
		resistance_debuff := 0, regen_factor := 1.0, attacker_path := NodePath()) -> Poisoned:
	var poisoning := of(target)
	if poisoning == null:
		print("  veneno: %s no tiene Poisoning" % _who(target))
		return null
	return poisoning.dose(per_second, lifetime, kind, from_slot, infectious, resistance_debuff, regen_factor, attacker_path)


func _ready() -> void:
	if body == null:
		body = get_parent() as Node3D
	if health == null and body:
		health = body.get_node_or_null("Health") as Health
	set_physics_process(is_multiplayer_authority())


## sacengine poison() (state.d:11601-11607): adds one dose of `per_second` for `lifetime` frames (lifetime + 1 updates).
## `resistance_debuff` is the SPEL's `ires`, `regen_factor` its `freg`. Server (or solo) only; null elsewhere.
func dose(per_second: float, lifetime: int, kind: StringName, from_slot: int, infectious := false, resistance_debuff := 0,
		regen_factor := 1.0, attacker_path := NodePath()) -> Poisoned:
	if not is_multiplayer_authority():
		return null
	var regen_before := regeneration_factor()
	var added := Poisoned.new()
	added.name = "Dose"
	added.per_second = per_second
	added.lifetime = maxi(0, lifetime)
	added.kind = kind
	added.from_slot = from_slot
	added.attacker_path = attacker_path
	added.ignore_friendly = true
	added.infectious = infectious
	added.resistance_debuff = resistance_debuff
	added.regeneration_factor = regen_factor
	added.mana_block_frame = MatchClock.ticks_for(mana_block_s)
	added.fx = dose_fx
	added.fx_socket = dose_socket
	added.fx_every_ticks = MatchClock.ticks_for(fx_every_s)
	add_child(added, true)
	_log_regeneration(regen_before)
	return added


func is_poisoned() -> bool:
	return not _doses().is_empty()


func resistance_bonus() -> float:
	var sum := 0
	for each in _doses():
		sum += each.resistance_debuff
	return 1e-3 * float(sum)


func regeneration_factor() -> float:
	var product := 1.0
	for each in _doses():
		product *= each.regeneration_factor
	return product


func mana_blocked() -> bool:
	for each in _doses():
		if each.blocks_mana:
			return true
	return false


func damage_sum() -> int:
	var sum := 0
	for each in _doses():
		sum += int(each.per_second)
	return sum


## True while an infection may not reach this body (sacengine infectionCooldown != 0).
func infection_cooling() -> bool:
	return MatchClock.now() < _infection_until


## sacengine infect(): infectionCooldown = lifetime + 3·updateFPS on the body just infected.
func start_infection_cooldown(lifetime: int) -> void:
	_infection_until = MatchClock.now() + lifetime + MatchClock.ticks_for(infection_cooldown_extra_s)


func _physics_process(_delta: float) -> void:
	if get_child_count() == 0:
		return
	var regen_before := regeneration_factor()
	var alive := can_be_poisoned()
	for current in _doses():
		if alive and current.infectious:
			_spread(current)
		var was_blocking := current.blocks_mana
		if not alive or health == null or not current.step(health):
			_end(current)
		elif current.blocks_mana and not was_blocking:
			print("%s maná bloqueado por %s (cuadro %d, tick %d)" % [_who(body), current.name, current.mana_block_frame, MatchClock.now()])
	_log_regeneration(regen_before)
	_log_mana()


## sacengine canBePoisoned (state.d:177-184): not dead or dying, not being summoned, not a ghost. A body a Sac Doctor has
## taken is off the field too (as for BodyNudge).
func can_be_poisoned() -> bool:
	if body == null or health == null or health.is_dead():
		return false
	if body is UnitBody:
		var unit := body as UnitBody
		return not unit.is_dead() and not unit.is_summoning() and not unit.is_taken()
	return not body.has_method("is_targetable") or bool(body.call("is_targetable"))  # dynamic: a wizard (or another body) answers it


func _spread(source: Poisoned) -> void:
	var area := BodyNudge.box(body).grow(infection_margin_m)
	var sum := damage_sum()
	var left := source.frames_left()
	for other in BodyNudge.bodies_in(get_tree(), area, groups):
		if other == body:
			continue
		var next := of(other)
		if next == null or next.infection_cooling():
			continue
		var verb := "reinfectado" if next.is_poisoned() else "infectado"
		next.dose(float(sum), left, source.kind, source.from_slot, true, source.resistance_debuff, source.regeneration_factor, source.attacker_path)
		next.start_infection_cooldown(left)
		print("%s %s por %s: %d/s, %d cuadros" % [_who(other), verb, _who(body), sum, left])


func _end(ended: Poisoned) -> void:
	if health:
		print(ended.end_line(_who(body), health))
	remove_child(ended)
	ended.queue_free()


func _doses() -> Array[Poisoned]:
	var list: Array[Poisoned] = []
	for child in get_children():
		if child is Poisoned:
			list.append(child as Poisoned)
	return list


func _log_regeneration(before: float) -> void:
	var now := regeneration_factor()
	if not is_equal_approx(now, before):
		print("%s regeneración ×%.2f" % [_who(body), now])


## The block of each dose is logged where it starts (_physics_process); here, the body's mana coming back.
func _log_mana() -> void:
	var now := mana_blocked()
	if now == _blocked:
		return
	_blocked = now
	if not now:
		print("%s maná libre (tick %d)" % [_who(body), MatchClock.now()])


## The node's name (Druid1, Druid2…): the log must tell apart bodies of the same kind.
static func _who(node: Node) -> String:
	return str(node.name) if node else "?"
