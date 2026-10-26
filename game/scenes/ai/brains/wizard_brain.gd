class_name AiWizardBrain
extends Node

## The brain of the AI's wizard (RFC-024 §3.1 `AiWizardBrain`; shiny.d:3303-3387 `wizBrain`). The task board calls `think`
## for the wizard when a record asks for it. Every 16 ticks of his age he replans: the weights of attacking, supporting and
## converting (weightTriple), the queue is emptied and every phase child fills it again. Then he casts the best entry he
## can pay (executeBestCast, shiny.d:3201-3280): if the target or the place is out of reach he walks toward it; if he
## cannot afford it a non-forced entry is skipped and a forced one waits for the next try; `lightCanCast` is the check
## (mana, souls, cooldown) that keeps the AI from asking for what the Caster would refuse. 024d adds: the souls he can take by
## touching them (within (1 - threat) * 100 + 80 m, shiny.d:3330-3337), the capture branch of a record with command 2
## (Manalith over a free fount, castCachedInRange; Desecrate of the enemy altar with the creature of most souls,
## pickGuardCreature) and the ghost (waits for his Manahoars or goes to the nearest mana building).

## After a replan of the wizard: the cast queue the phases left (diagnostic: the bench's decision log listens; nothing in the game does).
signal replanned(wizard: AiTrack, queue: Array)

@export var perception: AiPerception
@export var stance: AiStance
@export var groups: AiGroups
@export var port: AiCommandPort
@export var creature_brain: CreatureBrain
@export var profile: AiProfile

const CASTER := preload("res://scenes/spells/caster.gd")
## F371: what _shot_check answers.
const SHOT_OK := 0
const SHOT_WALKED := 1
const SHOT_VETOED := 2

var rng := AiRand.new()
var eval: AiSpellEval
var phases: Array[AiPhase] = []
var casts_started := 0
## Adenda 1.3 (AiDifficulty.summon_interval_s, mana_reserve): set by AiSide.setup. 0 and 0 = the original (Normal, Hard).
var summon_interval_ticks := 0
var mana_reserve := 0.0
## The port tick of the last summon he started (the summon interval counts from it).
var _last_summon_tick := -1000000
## RFC-053 (F371): the common sense of the difficulty (AiSide.setup sets it; Normal's until then).
var tactics: AiTactics
## F371: casts held back for want of a clear line (he walked closer) and for the burst they would take from his own bodies.
var line_walks := 0
var splash_vetoes := 0
## F372: queued Heals skipped because the body no longer needs them.
var heal_skips := 0
## F371: the walk toward a target he has no clear line to (its track id and where he was sent), kept while he walks to it.
var _line_target := 0
var _line_goal := Vector3.ZERO
## RFC-053: the attack spells on bodies (track id -> [the health the side knew at the last cast, tick its ban ends or 0]).
var _attack_marks: Dictionary = {}
## Diagnostic: bodies banned as futile spell targets.
var futile_bans := 0


func _ready() -> void:
	for child in get_children():
		if child is AiPhase:
			(child as AiPhase).brain = self
			phases.append(child)


## Called by AiSide.setup once the profile is set.
func prepare() -> void:
	tactics = AiTactics.or_normal(tactics)
	eval = AiSpellEval.new(perception, stance, groups, profile)
	eval.tactics = tactics


## wizBrain (shiny.d:3303-3387). Returns 1 when it gave an order or cast, 2 when it started a capture cast, 0 when it had nothing to do.
func think(wizard: AiTrack, cmd: int, record: AiRecord) -> int:
	if not wizard.is_valid():
		return 0
	if (wizard.node as WizardBody).is_ghost():
		return _ghost(wizard, cmd, record)
	## A cast decided and waiting its delay (Easy, 024e): he stands as if casting and orders nothing else (else he walked on toward
	## the fount and stood on it when the Manalith left: «Sin lugar»).
	if port.cast_pending():
		return 1
	if wizard.spell_dirty:
		rebuild_spells(wizard)
	if wizard.age >= wizard.next_replan:
		wizard.next_replan = wizard.age + profile.wizard_replan_age
		wizard.next_reissue = wizard.age - 1
		var w3 := AiField.weight_triple(cmd, stance.enemy_ratio(), profile.aggression)
		wizard.cast_queue.clear()
		for phase in phases:
			phase.run(wizard, w3, record if cmd == 2 else null)
		replanned.emit(wizard, wizard.cast_queue)
	## Souls he can take by touching (retail: 100 + 80 m scaled by the threat; the beta 80 + 60): first what he can cast in passing
	## (checkOnly), else he walks onto the soul.
	var reach := AiField.f32((1.0 - wizard.threat) * profile.soul_reach_scale + profile.soul_reach_base)
	if wizard.ord_state == 34:
		reach *= profile.soul_keep_factor
	var soul := perception.find_best_near(wizard.cur_pos, reach, true)
	if soul != null:
		if execute_best_cast(wizard, true) != 0:
			return 1
		port.order_go_to(wizard, 34, soul.cur_pos)
		return 1
	if record != null and cmd == 2:
		var captured := _capture_block(wizard, record)
		if captured != 0:
			return captured
	if execute_best_cast(wizard, false) != 0:
		return 1
	return creature_brain.think(wizard, cmd, record)


## The cmd 2 block of wizBrain (shiny.d:3354-3382): every 8 ages, at the target of his capture record, Desecrate (an altar) or Manalith
## (a free fount). Returns 2 when it started the cast.
func _capture_block(wizard: AiTrack, record: AiRecord) -> int:
	var tn := record.target
	if tn == null or wizard.age < wizard.next_reissue:
		return 0
	wizard.next_reissue = wizard.age + profile.wizard_reissue_age
	if tn.flags & AiTrack.ALTAR:
		## The desecrate path: an enemy altar not under ritual, the creature with most souls brought next to the wizard, and
		## the altar being the closest enemy one in range (the game's closestEnemyAltar).
		if wizard.desecrate_spell != null and (tn.flags & AiTrack.ENEMY) and not perception.desecration_against(tn):
			var guard := pick_guard_creature(tn)
			if guard != null and perception.closest_enemy_altar_in_range() == tn.node:
				var spell: SpellType = wizard.desecrate_spell
				var radius := AiField.f32(spell.cast_range_m * profile.desecrate_range_factor)
				if port.order_target_radius(guard, 3, wizard, radius) != 0:
					if enqueue_forced_execute(wizard, guard, spell, spell.cast_range_m, null) != 0:
						wizard.next_reissue += 7 * profile.wizard_reissue_age
						return 2
	elif (tn.flags & AiTrack.CAPTURABLE) and (tn.status & AiTrack.UNBUILT):
		if cast_cached_in_range(wizard, tn) != 0:
			return 2
	return 0


## pickGuardCreature (shiny.d:3026-3050, 0x485700): of the own creatures (not the wizard) the one that weighs most
## (1 within 10 m of the target, falling linearly to 0 at 3620 m) times its souls; a strict argmax from 0, so a creature of 0 souls
## is never picked. Deviation: the game's own test `sacrifice_status` (alive, free, not held, a Captive) filters the candidates first,
## so the AI never asks Desecrate for a creature that would answer «Blanco inválido» (sacengine tests the mode after picking). A creature
## bound by the Guardian spell is skipped (isGuardianEnt, shiny.d:3032).
func pick_guard_creature(target: AiTrack) -> AiTrack:
	var best := 0.0
	var best_track: AiTrack
	var system := perception.sacrifice()
	for c: AiTrack in perception.bodies(0):
		if c.kind == AiTrack.Kind.WIZ or not c.is_valid():
			continue
		## isGuardianEnt (shiny.d:3032): a creature bound to a building by the Guardian spell is never the victim.
		if c.is_guardian_bound():
			continue
		if system != null and not system.sacrifice_status(perception.slot, c.node).is_empty():
			continue
		var worth := AiGroups.souls_pair(c).x
		var d := c.extrap_pos.distance_to(target.cur_pos)
		var w := 0.0
		if d <= 10.0:
			w = 1.0
		elif d < 3620.0:
			w = (3620.0 - d) * 0.0002770083083305508
		var v := w * float(worth)
		if best < v:
			best = v
			best_track = c
	if best_track != null and best_track.group != null:
		(best_track.group as AiGroup).members.erase(best_track)
		best_track.group = null
	return best_track


## castCachedInRange (shiny.d:3285-3301, 0x48dce0): the Manalith spell, forced, when the wizard is within range * sqrt(1.4) * 5 of the
## fount and the threat is under 0.9 (retail; the beta 0.6). The fount must still be free (canCastSpellOn's onlyManafounts reads it live).
func cast_cached_in_range(wizard: AiTrack, fount: AiTrack) -> int:
	var shrine: SpellType = wizard.shrine_spell
	if shrine == null or wizard.threat >= profile.build_threat_cap:
		return 0
	if not fount.is_valid() or not (fount.node as ManafountBody).is_free():
		return 0
	var r := float(shrine.cast_range_m)
	r = r * r * 1.399999976158142 * 25.0
	if wizard.cur_pos.distance_squared_to(fount.cur_pos) > r:
		return 0
	return enqueue_forced_execute(wizard, fount, shrine, shrine.cast_range_m, null)


## enqueueForcedExecute (shiny.d:3290, 0x48d080): score 0, forced, and straight to the execution.
func enqueue_forced_execute(wizard: AiTrack, target: AiTrack, spell: Resource, range_m: float, obj: AiTrack) -> int:
	AiCastQueue.enqueue(wizard.cast_queue, AiCastQueue.make(AiCastQueue.FORCED, 0.0, target, spell, range_m, obj))
	return execute_best_cast(wizard, false)


## The ghost (shiny.d:3306-3326): his own Manahoars within 256 m will channel him back, so he waits; with none near he goes to the
## nearest mana building of his side (altar, Manalith). That last part is a deliberate deviation of sacengine, not of thaum.
func _ghost(wizard: AiTrack, cmd: int, record: AiRecord) -> int:
	for t: AiTrack in perception.bodies(0):
		if t.kind == AiTrack.Kind.MAHO and wizard.cur_pos.distance_squared_to(t.cur_pos) <= 256.0 * 256.0:
			return creature_brain.think(wizard, cmd, record)
	var best: AiTrack
	var best_d := INF
	for t: AiTrack in perception.structures(0):
		if not t.is_valid() or not ((t.flags & AiTrack.ALTAR) or (t.status & AiTrack.MANALITH)):
			continue
		var d := wizard.cur_pos.distance_squared_to(t.cur_pos)
		if d < best_d:
			best_d = d
			best = t
	if best != null:
		port.order_if_changed(wizard, 3, best, null)
		return 1
	return creature_brain.think(wizard, cmd, record)


## A target that still exists and is not dying (the Caster would answer "Blanco inválido").
static func target_alive(t: AiTrack) -> bool:
	if t == null or not t.is_valid():
		return false
	return not (t.node.has_method("is_dead") and bool(t.node.call("is_dead")))  # dynamic: unit, structure and doctor bodies answer it


## wizSpellRebuild (shiny.d:2610-2636): the book of the wizard in the lists the phases read.
func rebuild_spells(wizard: AiTrack) -> void:
	wizard.summons = []
	wizard.spell_accs = []
	wizard.manahoar_spell = null
	wizard.shrine_spell = null
	wizard.convert_spell = null
	wizard.desecrate_spell = null
	var book := wizard.node.get_node("Spellbook") as Spellbook
	for i in book.creature_count():
		var type := book.creature_at(i)
		if type == null:
			continue
		if type.tag == AiPerception.MAHO_TAG:
			wizard.manahoar_spell = type
		else:
			wizard.summons.append({"tag": type.tag, "type": type, "acc": perception.tag_acc(type)})
	for i in book.size():
		var spell := book.spell_at(i)
		if spell != null and AiSpellEval.wants_acc(spell):
			wizard.spell_accs.append({"spell": spell, "fn": AiSpellEval.rating_fn(spell)})
	for i in book.structure_count():
		var spell := book.structure_at(i)
		if spell == null:
			continue
		if wizard.shrine_spell == null and spell.only_free_manafounts:
			wizard.shrine_spell = spell
		if spell.ai_use == SpellType.AiUse.CONVERT:
			wizard.convert_spell = spell
		if spell.ai_use == SpellType.AiUse.DESECRATE:
			wizard.desecrate_spell = spell
	wizard.spell_dirty = false


## lightCanCast (shiny.d:3174-3199): mana, souls, cooldown and a free wizard. The mana test is the Caster's own (cost <= mana
## + epsilon; sacengine rounds with ftol), so the AI never asks for what the Caster would answer «Sin maná».
func light_can_cast(wizard: AiTrack, spell: Resource) -> bool:
	var node := wizard.node as WizardBody
	if not node.can_cast():
		return false
	## a cast decided and waiting its delay (Easy, 024e) keeps him busy like one being cast
	if port != null and port.cast_pending():
		return false
	var caster := node.get_node("Caster") as Caster
	if caster.is_casting():
		return false
	var book := node.get_node("Spellbook") as Spellbook
	var cooldown := 0.0
	if spell is CreatureType:
		var purse := node.get_node_or_null("SoulPurse")
		if (purse != null and int(purse.get("count")) < (spell as CreatureType).souls) or purse == null:
			return false
		cooldown = book.creature_cooldown(book.creature_index_of((spell as CreatureType).tag))
	elif spell is SpellType:
		var tag := (spell as SpellType).tag
		if bool((spell as SpellType).is_structure):
			cooldown = book.structure_cooldown(book.structure_index_of(tag))
		else:
			cooldown = book.cooldown(book.index_of(tag))
	else:
		return false
	if cooldown > 0.0:
		return false
	var cost := maxf(CASTER.MIN_MANA_COST, float(spell.get("mana_cost")))
	return cost <= AiPerception._mana_now(node) + CASTER.MANA_EPSILON


## 024e: what a cast that waited its delay (Easy) checks again when it leaves the port: lightCanCast, and for an entry with an action
## (Manalith, Convert, Desecrate) the game's own check of it (Caster.action_status: the fount still has room, the soul is still free, the
## enemy altar still in range), so the half second never turns into a refusal. `point` is where it was going to be cast.
## Returns "" when it can go, else why not.
func cast_refusal(wizard: AiTrack, spell: Resource, target: AiTrack, point: Vector3) -> String:
	if not light_can_cast(wizard, spell):
		return "lightCanCast"
	if not (spell is SpellType and bool((spell as SpellType).is_structure)):
		return ""
	var caster := wizard.node.get_node("Caster") as Caster
	var picked: Node3D = target.node if target != null and target.is_valid() else null
	return caster.action_status((spell as SpellType).tag, point, picked)


## Adenda 1.3: the summon interval of the difficulty has passed since his last summon (always true with interval 0).
func summon_interval_over() -> bool:
	return summon_interval_ticks <= 0 or port.now_tick() - _last_summon_tick >= summon_interval_ticks


## Adenda 1.3: a creature of `mana_cost` leaves him at least the reserve of the difficulty (always true with reserve 0).
func keeps_reserve(wizard: AiTrack, mana_cost: float) -> bool:
	if mana_reserve <= 0.0:
		return true
	return AiPerception._mana_now(wizard.node) - mana_cost >= mana_reserve * AiPerception._mana_max(wizard.node)


## executeBestCast (shiny.d:3201-3280). `check_only` is the soul-pickup test; 024c always passes false.
func execute_best_cast(wizard: AiTrack, check_only: bool) -> int:
	var queue := wizard.cast_queue
	var i := 0
	while i < queue.size():
		var e: Dictionary = queue[i]
		var forced := (int(e["flag"]) & AiCastQueue.FORCED) != 0
		var target: AiTrack = e["target"]
		var obj: AiTrack = e["obj"]
		var spell: Resource = e["spell"]
		if spell == null or (forced and target != null and check_only):
			i += 1
			continue
		## No Manalith: only what the wizard can pay now (shiny.d:3216-3224).
		if stance.manalith_count() == 0:
			var cost := maxf(CASTER.MIN_MANA_COST, float(spell.get("mana_cost")))
			if cost > AiPerception._mana_now(wizard.node) + CASTER.MANA_EPSILON:
				if forced:
					return 0
				i += 1
				continue
		if target != null and not target_alive(target):
			i += 1
			continue
		## F372 (RFC-053 053c): a Heal is scored again against the health the side knows now; one no longer needed is skipped.
		if target != null and not eval.still_worth(spell, target):
			heal_skips += 1
			i += 1
			continue
		if obj != null:
			if target != null and target.kind == AiTrack.Kind.WIZ and (target.node as WizardBody).is_ghost():
				i += 1
				continue
			var range_m := float(e["range"])
			if wizard.cur_pos.distance_squared_to(obj.cur_pos) > range_m * range_m:
				if not check_only:
					port.order_pos_radius(wizard, 2, obj.cur_pos, range_m)
					return 1
				i += 1
				continue
		if not light_can_cast(wizard, spell):
			if not forced:
				i += 1
				continue
			if obj == null:
				return 0
			if not check_only:
				port.order_target_radius(wizard, 3, obj, float(e["range"]))
				return 1
			i += 1
			continue
		## Without perfect information (024e) a body the side does not see now cannot be clicked: the entry is skipped (he went
		## toward where it was seen; if it is there his sight marks it and the next try casts).
		if target != null and not port.can_aim(target):
			i += 1
			continue
		## F371: the line of fire and sight (shiny.d:3254-3270) and the burst on his own bodies.
		var shot := _shot_check(wizard, target, spell, check_only)
		if shot == SHOT_WALKED and not check_only:
			return 1
		if shot != SHOT_OK:
			i += 1
			continue
		var point := obj.cur_pos if obj != null else wizard.cur_pos
		port.start_casting(spell, target, point)
		casts_started += 1
		_note_attack_cast(spell, target)
		if spell is CreatureType:
			_last_summon_tick = port.now_tick()
		queue.remove_at(i)
		return 1
	return 0


## F371 (RFC-053 053b): an attack spell on a body goes only with a clear line; without one the wizard walks `los_retry_factor` of the way
## to the target and tries again (shiny.d:3262). A splash spell (Wrath, Fireball, Swarm) is held back when its burst, where it would
## really burst (the blocker if any, else the target), takes more than `own_splash_max_ratio` of the health of an own body. Returns
## SHOT_OK (cast), SHOT_WALKED (no clear line: sent closer, but not when `check_only`) or SHOT_VETOED (skip the entry).
func _shot_check(wizard: AiTrack, target: AiTrack, spell: Resource, check_only: bool) -> int:
	if not (spell is SpellType) or target == null or not target.is_valid() or target.node == wizard.node:
		return SHOT_OK
	var type := spell as SpellType
	if type.is_structure or not AiSpellEval.casts_in(type, SpellType.AiPhase.ATTACK):
		return SHOT_OK
	var body := wizard.node as WizardBody
	var splash := AiLineOfFire.is_splash(body, type)
	if not tactics.los_check and not splash:
		return SHOT_OK
	var line := AiLineOfFire.trace(body, target.node, type)
	var blocker: Node3D = line["blocker"]
	if tactics.los_check and blocker != null:
		if not check_only:
			_walk_for_line(wizard, target)
		return SHOT_WALKED
	_line_target = 0
	if splash and eval.own_splash(line["point"], type, blocker if blocker != null else target.node) > tactics.own_splash_max_ratio:
		splash_vetoes += 1
		return SHOT_VETOED
	return SHOT_OK


## Walks `los_retry_factor` of the distance to where the side knows the target; while he walks to that spot it is not moved.
func _walk_for_line(wizard: AiTrack, target: AiTrack) -> void:
	var walking := (wizard.node as WizardBody).is_walking()
	if _line_target != target.id or not walking or wizard.cur_pos.distance_squared_to(_line_goal) <= 4.0:
		_line_goal = wizard.cur_pos.lerp(target.cur_pos, tactics.los_retry_factor)
		_line_target = target.id
	line_walks += 1
	port.order_go_to(wizard, 2, _line_goal)


## RFC-053: a body the side's attack spells do not bring down is not a spell target until its ban ends.
func spell_futile(target: AiTrack) -> bool:
	var mark: Array = _attack_marks.get(target.id, [])
	if mark.is_empty() or int(mark[1]) == 0:
		return false
	if port.now_tick() < int(mark[1]):
		return true
	_attack_marks.erase(target.id)
	return false


## An attack spell started on a body: if what it lost since the last one (the health the side knows), spell_kill_max_casts times over,
## would not bring it down, it is banned for spell_futile_forget_s.
func _note_attack_cast(spell: Resource, target: AiTrack) -> void:
	if tactics == null or tactics.spell_futile_forget_s <= 0.0 or target == null or not target.is_body():
		return
	if not (spell is SpellType) or (spell as SpellType).is_structure or not AiSpellEval.casts_in(spell as SpellType, SpellType.AiPhase.ATTACK):
		return
	var health := perception.health_of(target)
	var mark: Array = _attack_marks.get(target.id, [])
	if DebugLog.on(&"ai_attack"):
		print("ai_attack slot %d hechizo %s sobre %s: vida conocida %d de %d, antes %s, ve %s" % [perception.slot, (spell as SpellType).tag,
			target.node.name, health.x, health.y, str(mark[0]) if not mark.is_empty() else "-", str(perception.knows_live(target))])
	if not mark.is_empty() and health.y > 0 and (int(mark[0]) - health.x) * tactics.spell_kill_max_casts < health.x:
		mark[1] = port.now_tick() + MatchClock.ticks_for(tactics.spell_futile_forget_s)
		futile_bans += 1
		if DebugLog.on(&"ai_attack"):
			print("ai_attack slot %d hechizo inutil sobre %s: vida %d antes %d de %d" % [perception.slot, target.node.name, health.x,
				int(mark[0]), health.y])
	else:
		mark = [health.x, 0]
	mark[0] = health.x
	_attack_marks[target.id] = mark

