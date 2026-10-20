class_name SummonPhase
extends AiPhase

## wizSacrifice (shiny.d:3115-3172, 0x48d8b0): what the wizard summons. With no souls it does nothing, the Manahoar
## included (a creature costs its souls when the cast ends). Otherwise:
## BLOCK1 (shiny.d:3123-3137): when rand >= threat * 1.3, a Manahoar is forced if there is a Manalith (own or ally, retail), a
## Manahoar spell, and fewer ready Manahoars than souls/2; and either none is ready or the mana deficit per Manalith and ready
## Manahoar is above 1400. A forced Manahoar is the only thing queued this replan.
## BLOCK2 (shiny.d:3139-3171): with threat < 0.6 and a pool of mana (maxMana x Manaliths) > 0, the creature of the book (not
## the Manahoar) the wizard can pay in souls with the best score `rateWithBase(creature, field) x (1 - cost/pool)` is
## forced. The Manaliths count because the pool is maxMana x Manaliths: with none, the original summons nothing (so a
## match starts with its Manalith, see debug/ai_summon). The «field» is the quirky mix of acc1 and acc2 (see AiStance).
## RFC-053 (deviation): in the BLOCK2 test the hostile NPC around the wizard weigh AiTactics.npc_summon_threat_weight (0 in every
## difficulty): measured in ai_easy_vs_normal seed 7 with NPC, two Taurocks by the East fount kept the Easy wizard's threat at
## 0.64-0.86 for minutes, so he never summoned again while his souls piled up («se queda quieta con muchas almas»). And the pool
## counts at least AiTactics.summon_min_manaliths Manaliths (1): in the same match the Taurocks broke both Manaliths and neither side
## could summon again (BLOCK1, the Manahoar, still needs a Manalith to channel: unchanged).


func run(wizard: AiTrack, _w3: Array[float], _record: AiRecord) -> void:
	var profile := brain.profile
	var node := wizard.node
	var max_mana := AiRater.ftol(AiPerception._mana_max(node))
	var purse := node.get_node_or_null("SoulPurse")
	var souls := int(purse.get("count")) if purse != null else 0
	if max_mana == 0 or souls == 0:
		return
	## Adenda 1.3: the difficulty's own pace (Easy): no summon before its interval has passed. Normal and Hard: always over.
	if not brain.summon_interval_over():
		_note(wizard, "intervalo")
		return
	var stance := brain.stance
	var randv := brain.rng.unit()
	var threatv := AiField.f32(wizard.threat * profile.emergency_threat_factor)
	var manaliths := stance.manalith_count()
	if randv >= threatv:
		if manaliths > 0 and wizard.manahoar_spell != null:
			var ready := 0
			for group: AiGroup in brain.groups.list(0):
				ready += group.ready_count
			@warning_ignore("integer_division")
			var ready_cap := stance.recs[0].souls_all / profile.ready_divisor
			if ready < ready_cap:
				var deficit := 2 * stance.recs[0].max_mana - stance.recs[0].mana
				if ready == 0 or AiField.safediv(float(deficit), float(manaliths * ready)) > profile.emergency_mana_ratio:
					AiCastQueue.enqueue(wizard.cast_queue, AiCastQueue.make(AiCastQueue.FORCED, 0.0, null, wizard.manahoar_spell, 0.0, null))
					return
	if not (_summon_threat(wizard) < profile.summon_threat_cap):
		_note(wizard, "amenaza %.2f (para convocar %.2f)" % [wizard.threat, _summon_threat(wizard)])
		return
	var pool := max_mana * maxi(manaliths, brain.tactics.summon_min_manaliths if brain.tactics != null else 0)
	if pool == 0 or wizard.summons.is_empty():
		_note(wizard, "sin pozo (manalitos %d)" % manaliths)
		return
	var best_score := 0.0
	var best_spell: CreatureType
	var share := stance.enemy_ratio()
	for entry: Dictionary in wizard.summons:
		var type: CreatureType = entry["type"]
		if type.souls > souls:
			continue
		## Adenda 1.3: the mana the difficulty keeps (Easy) is not spent on a creature. Normal and Hard: no reserve.
		if not brain.keeps_reserve(wizard, type.mana_cost):
			continue
		var field := AiRater.new_acc()
		AiRater.combine(field, 1.0, stance.acc1, share)
		AiRater.combine(field, 1.0, stance.acc2, AiField.f32(1.0 - share))
		var rating := AiRater.rate_with_base(entry["acc"], field)
		var score := AiField.summon_score(rating, type.mana_cost, pool)
		if best_spell == null or best_score < score:
			best_score = AiField.f32(score)
			best_spell = type
	_note(wizard, "elige %s, almas %d" % [best_spell.tag if best_spell != null else "-", souls])
	if best_spell != null:
		AiCastQueue.enqueue(wizard.cast_queue, AiCastQueue.make(AiCastQueue.FORCED, 0.0, null, best_spell, 0.0, null))


## The threat BLOCK2 compares with summon_threat_cap: the wizard's threat less the share of it that hostile NPC make, by
## (1 - npc_summon_threat_weight).
func _summon_threat(wizard: AiTrack) -> float:
	var weight := brain.tactics.npc_summon_threat_weight if brain.tactics != null else 1.0
	if weight >= 1.0 or wizard.threat <= 0.0:
		return wizard.threat
	var share := brain.stance.npc_share(wizard.extrap_pos, brain.profile.threat_far)
	return AiField.f32(wizard.threat * (1.0 - share * (1.0 - weight)))


func _note(wizard: AiTrack, why: String) -> void:
	if DebugLog.on(&"ai_summon"):
		print("ai_summon slot %d tick %d %s" % [brain.perception.slot, brain.port.now_tick(), why])
