extends RefCounted

## 055f f5 case of rules_suite: the AI uses all its spells. Each of the 13 spells of plan 055f §12 has its use and phase, and its
## evaluator (scenes/ai/brains/ratings/) rates it over 0 in its situation and 0 in the contrary one: Halo with two foes near and with
## one, Charm on an enemy creature and on a wizard, Death and Meanstalks on a foe and on what they do not land on, Rainbow and Healing
## Aura on hurt own bodies and on a healthy one, Animate Dead on an own corpse's soul and on a free soul, Soul Wind and Soul Mole on a
## soul out of the wizard's touching reach and inside it, Teleport with a high and a low threat, Guardian with a pressed building and
## without. Shrine is the capture's (CaptureCasts) and Bore never. Also: the Caster's answer Casting asks (AiCastOut.status).
## Prints AI SPELL USE checked=<n> failed=<n> and each failed check.

const WORLD := preload("res://debug/suite/soul_world.gd")
const RIG := preload("res://debug/suite/ai_perception_rig.tscn")
## The lab's book: every spell of the table, so the Caster knows them all.
const MIXED_BOOK: GodBook = preload("res://debug/ai/ai_mixed_book.tres")
## tag -> [evaluator, phase] (plan 055f §12).
const USES := {
	"olah": [AiSpellEval.FN_SELF_AREA, SpellType.AiPhase.ATTACK], "mrhc": [AiSpellEval.FN_TAKE_FOE, SpellType.AiPhase.ATTACK],
	"taed": [AiSpellEval.FN_AREA, SpellType.AiPhase.ATTACK], "rter": [AiSpellEval.FN_AREA, SpellType.AiPhase.ATTACK],
	"wobr": [AiSpellEval.FN_HEAL_AREA, SpellType.AiPhase.SUPPORT], "ruah": [AiSpellEval.FN_HEAL_AREA, SpellType.AiPhase.SUPPORT],
	"deda": [AiSpellEval.FN_RAISE_DEAD, SpellType.AiPhase.SUPPORT], "dnws": [AiSpellEval.FN_GATHER_SOULS, SpellType.AiPhase.SUPPORT],
	"pmcd": [AiSpellEval.FN_GATHER_SOULS, SpellType.AiPhase.SUPPORT], "elet": [AiSpellEval.FN_ESCAPE, SpellType.AiPhase.SUPPORT],
	"ndrg": [AiSpellEval.FN_GUARD_SITE, SpellType.AiPhase.SUPPORT], "pcas": [AiSpellEval.FN_NONE, SpellType.AiPhase.NEVER],
	"erob": [AiSpellEval.FN_NONE, SpellType.AiPhase.NEVER],
}

var _w := WORLD.new()
var _checks := {}


func run(host: Node3D) -> Dictionary:
	_w.build(host, "AiSpellUseCases")
	_uses()
	await _situations()
	_w.clear()
	var failed := PackedStringArray()
	for key: String in _checks:
		if not bool(_checks[key]):
			failed.append(key)
	print("AI SPELL USE checked=%d failed=%d" % [_checks.size(), failed.size()])
	for key in failed:
		print("AI SPELL USE   falla " + key)
	return {"ai_spell_use": {"ok": failed.is_empty() and _checks.size() > 0, "checks": _checks}}


func _uses() -> void:
	for tag: String in USES:
		var spell := GameData.spell(tag)
		var row: Array = USES[tag]
		_checks[tag + "_use"] = spell != null and AiSpellEval.rating_fn(spell) == int(row[0]) and spell.ai_phase == int(row[1])
	var shrine := GameData.spell("pcas")
	_checks["pcas_by_capture"] = shrine != null and shrine.is_structure and shrine.only_free_manafounts and not AiSpellEval.wants_acc(shrine)
	_checks["gather_fits"] = AiGatherSouls.fits(95.0, 90.0, 100.0) and not AiGatherSouls.fits(60.0, 90.0, 100.0) \
		and not AiGatherSouls.fits(120.0, 90.0, 100.0)


func _situations() -> void:
	var perception: AiPerception = RIG.instantiate()
	perception.name = "AiSpellUsePerception"
	perception.play = AiPlay.normal()
	perception.slot = 1
	_w.root.add_child(perception)
	var tactics := perception.play.tactics
	var wizard := _w.wizard(1, Vector3.ZERO, "persephone", 8)
	wizard.book = MIXED_BOOK
	var foe_far := _w.unit(Vector3(500.0, 0.0, 500.0), 3)
	var foe_a := _w.unit(Vector3(10.0, 0.0, 0.0), 3)
	var foe_b := _w.unit(Vector3(0.0, 0.0, 10.0), 3)
	var hurt_a := _w.unit(Vector3(-10.0, 0.0, 0.0), 1)
	var hurt_b := _w.unit(Vector3(-12.0, 0.0, 2.0), 1)
	var healthy := _w.unit(Vector3(-150.0, 0.0, 0.0), 1)
	await _w.frames(3)
	(hurt_a.get_node("Health") as Health).current = 1000.0
	(hurt_b.get_node("Health") as Health).current = 1000.0
	var me := perception.add_node(wizard, &"event")
	var a := perception.add_node(foe_a, &"event")
	var b := perception.add_node(foe_b, &"event")
	var ha := perception.add_node(hurt_a, &"event")
	var hb := perception.add_node(hurt_b, &"event")
	var fine := perception.add_node(healthy, &"event")
	var lone := perception.add_node(foe_far, &"event")
	_checks["tracked"] = me != null and a != null and b != null and ha != null and hb != null and fine != null and lone != null
	if bool(_checks["tracked"]):
		for t: AiTrack in [me, a, b, ha, hb, fine, lone]:
			t.cached_rate = 1.0
		var stance := AiStance.new()
		stance.recs[0].manaliths = 1
		var groups := AiGroups.new()
		groups.perception = perception
		_w.root.add_child(groups)
		groups.rebuild()
		var eval := AiSpellEval.new(perception, stance, groups, tactics)
		_attack(eval, me, a, b, ha, lone)
		_support(perception, tactics, ha, fine, a)
		await _souls(eval, perception, tactics, wizard, me)
		_escape_and_guard(perception, tactics, me, ha, a)
		stance.free()
		groups.queue_free()
	for node: Node in [perception, wizard, foe_far, foe_a, foe_b, hurt_a, hurt_b, healthy]:
		node.queue_free()
	await _w.frames(2)


## `lone`: a foe far from every own body, so an area spell on it takes nothing of his side.
func _attack(eval: AiSpellEval, me: AiTrack, a: AiTrack, b: AiTrack, own: AiTrack, lone: AiTrack) -> void:
	var halo := GameData.spell("olah")
	_checks["olah_two_foes_near"] = AiSelfArea.rate(halo, me, eval.perception.bodies(3), eval.tactics) > 0.0
	_checks["olah_lands_on_him"] = AiSpellUses.aim(eval, me, halo, a) == me and eval.rate(me, halo, me, 0.0, a) > 0.0
	var at := b.cur_pos
	b.cur_pos = Vector3(300.0, 0.0, 0.0)
	_checks["olah_one_foe_zero"] = AiSelfArea.rate(halo, me, eval.perception.bodies(3), eval.tactics) == 0.0
	b.cur_pos = at
	var charm := GameData.spell("mrhc")
	_checks["mrhc_enemy_creature"] = AiTakeFoe.rate(charm, me, a) > 0.0
	_checks["mrhc_not_a_wizard"] = AiTakeFoe.rate(charm, me, me) == 0.0 and AiTakeFoe.rate(charm, me, own) == 0.0
	for tag: String in ["taed", "rter"]:
		var spell := GameData.spell(tag)
		_checks[tag + "_on_a_foe"] = eval.rate(me, spell, lone, 0.0) > 0.0
		var soul := AiTrack.new()
		soul.node = Node3D.new()
		_checks[tag + "_not_on_a_soul"] = not AiSpellEval.lands_on(spell, soul)
		soul.node.free()
	_checks["rter_not_on_own"] = eval.rate(me, GameData.spell("rter"), own, 0.0) == 0.0


func _support(perception: AiPerception, tactics: AiTactics, hurt: AiTrack, healthy: AiTrack, foe: AiTrack) -> void:
	for tag: String in ["wobr", "ruah"]:
		var spell := GameData.spell(tag)
		_checks[tag + "_hurt_own"] = AiHealArea.rate(spell, hurt, perception, tactics) > 0.0
		_checks[tag + "_healthy_zero"] = AiHealArea.rate(spell, healthy, perception, tactics) == 0.0
		_checks[tag + "_not_a_foe"] = AiHealArea.rate(spell, foe, perception, tactics) == 0.0


func _souls(eval: AiSpellEval, perception: AiPerception, tactics: AiTactics, wizard: WizardBody, me: AiTrack) -> void:
	var dead := await _w.corpse_with_soul(Vector3(20.0, 0.0, 0.0), 1)
	var foe_dead := await _w.corpse_with_soul(Vector3(0.0, 0.0, 30.0), 3)
	var free_near := _w.free_soul(Vector3(0.0, 0.0, -40.0))
	var free_far := _w.free_soul(Vector3(190.0, 0.0, 0.0))
	var free_mid := _w.free_soul(Vector3(0.0, 0.0, -95.0))
	var raise := GameData.spell("deda")
	var aimed := AiRaiseDead.aim(me, raise, perception)
	_checks["deda_own_corpse"] = aimed != null and aimed.node == _w.soul_of(dead) and AiRaiseDead.rate(aimed, perception.slot) > 0.0
	_checks["deda_free_soul_zero"] = AiRaiseDead.rate(perception.souls.soul_track(free_near), perception.slot) == 0.0
	var foe_soul := _w.soul_of(foe_dead)
	_checks["deda_foe_soul_zero"] = foe_soul != null and AiRaiseDead.rate(perception.souls.soul_track(foe_soul), perception.slot) == 0.0
	_checks["deda_only_looking_at_him"] = AiSpellUses.aim(eval, me, raise, perception.find(dead)) == null
	var mole := GameData.spell("pmcd")
	var wind := GameData.spell("dnws")
	me.threat = 0.0
	## 055f f5: calm, he sends for the nearest soul farther than a short walk (soul_send_min_m), not only for the ones out of his reach.
	var far := AiGatherSouls.aim(me, mole, perception, tactics)
	_checks["pmcd_beyond_short_walk"] = far != null and far.node == free_mid and AiGatherSouls.rate(mole, me, far, perception) > 0.0
	var mid_at := free_mid.global_position
	free_mid.global_position = Vector3(0.0, 0.0, -20.0)
	_checks["dnws_all_a_short_walk_zero"] = AiGatherSouls.aim(me, wind, perception, tactics) == null
	free_mid.global_position = mid_at
	me.threat = 0.9
	var mid := AiGatherSouls.aim(me, wind, perception, tactics)
	_checks["dnws_out_of_reach"] = mid != null and mid.node == free_mid and AiGatherSouls.rate(wind, me, mid, perception) > 0.0
	me.threat = 0.0
	var out := AiCastOut.new()
	out.bind(perception.slot, wizard, null)
	var own_soul := perception.souls.soul_track(_w.soul_of(dead))
	_checks["caster_takes_own_corpse"] = out.status(raise, own_soul, own_soul.cur_pos).is_empty()
	_checks["caster_refuses_free_soul"] = out.status(raise, perception.souls.soul_track(free_near), free_near.global_position) == SpellAction.BAD_TARGET
	for node: Node in [dead, foe_dead, free_near, free_far, free_mid]:
		if is_instance_valid(node):
			node.queue_free()


func _escape_and_guard(perception: AiPerception, tactics: AiTactics, me: AiTrack, own: AiTrack, foe: AiTrack) -> void:
	var home := _site(Vector3(400.0, 0.0, 0.0))
	var post := _site(own.cur_pos)
	var sites: Array = perception.structures(0)
	sites.append(home)
	sites.append(post)
	me.threat = 0.9
	_checks["elet_high_threat"] = AiEscape.aim(me, perception, tactics) == home and AiEscape.rate(me, tactics) > 0.0
	me.threat = tactics.escape_threat - 0.2
	_checks["elet_low_threat_zero"] = AiEscape.aim(me, perception, tactics) == null and AiEscape.rate(me, tactics) == 0.0
	me.threat = 0.0
	_checks["ndrg_pressed_site"] = AiGuardSite.rate(own, perception, tactics) > 0.0
	_checks["ndrg_not_a_foe"] = AiGuardSite.rate(foe, perception, tactics) == 0.0
	post.cur_pos = Vector3(-400.0, 0.0, -400.0)
	_checks["ndrg_no_pressed_site_zero"] = AiGuardSite.rate(own, perception, tactics) == 0.0
	sites.erase(home)
	sites.erase(post)
	home.node.free()
	post.node.free()


## An own building of the side for the cases: an altar track at `at` (not in the tree; the evaluators read its track only).
func _site(at: Vector3) -> AiTrack:
	var t := AiTrack.new()
	t.kind = AiTrack.Kind.STRUCTURE
	t.site = AiTrack.Site.ALTAR
	t.relation = AiTrack.Relation.OWN
	t.node = Node3D.new()
	t.cur_pos = at
	return t
