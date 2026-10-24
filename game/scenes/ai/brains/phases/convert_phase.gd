class_name ConvertPhase
extends AiPhase

## wizRetreat (shiny.d:3088-3114, 0x48db60): the wizard converts the red souls he cannot take by touching them, the NPC of the villages
## included (their souls are red for both players, state.d:1621): the cast of Convert (`ccas`) on the best of them, within
## v = (1 - own share of souls) * (1 - threat) * aggression * 500 m. Conditions: he has an altar of his own standing (where the
## creature is taken), the book has Convert and that altar is not being desecrated. The entry is queued with
## `(1 - threat) * w3[2] * 0.9`, target and obj the soul (thaum passes obj 0 and never approaches; sacengine gates the range, so it
## approaches: shiny.d:3112). The cast waits for mana (800) like any other: `lightCanCast`. Take the node out and the AI never
## converts: its souls would come only from its creatures' deaths (the blue ones) and from the souls it touches.


func run(wizard: AiTrack, w3: Array[float], _record: AiRecord) -> void:
	var perception := brain.perception
	if wizard.convert_spell == null or not perception.has_home_altar():
		return
	var home := perception.sacrifice().closest_own_site(perception.slot, wizard.node.global_position)
	if home != null and perception.sacrifice().desecration_against(home.owner_slot()):
		return
	var profile := brain.profile
	var v := AiField.f32((1.0 - brain.stance.enemy_ratio()) * (1.0 - wizard.threat) * profile.aggression * profile.convert_reach_m)
	if v <= 10.0:
		return
	var soul := perception.find_best_near(wizard.cur_pos, v, false)
	if soul == null:
		return
	var spell: SpellType = wizard.convert_spell
	AiCastQueue.enqueue(wizard.cast_queue, AiCastQueue.make(0, AiField.f32((1.0 - wizard.threat) * w3[2] * profile.convert_score_factor), soul, spell, spell.cast_range_m, soul))
