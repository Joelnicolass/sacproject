class_name AttackPhase
extends AiPhase

## What the wizard attacks: among the enemy bodies the side knows (creatures, wizards,
## the NPC of the villages) within (1 - threat) * 280 m, the one of most weight (1 within 10 m, falling linearly to 0; the
## tactics' weight_passive if it does not fight, weight_no_ability if it has no ability it can pay, weight_sac_doctor a Sac Doctor)
## is the target, and the book's attack with the best score against it is queued with the score `best * w3[0] / total` (on the
## body the spell aims at: himself for a burst around him, AiSpellEval.find_best).
## It uses what the AI KNOWS: an enemy it has not seen stays where it was when taken in.
## RFC-053 053b (F371): a passive NPC (a body of an NPC slot that never picks a fight: CRE8 aggressiveness 0, or a peasant, whose
## VillagerBrain never attacks) weighs AiTactics.npc_passive_weight more (0 in every difficulty: «la IA no los caza a propósito»,
## PRD). Measured in f371_npc before the change: the first replan took a Farmer at 20 m (threat 0.000, enemy_ratio 0.167) with the
## Druid at 40 m in range, and Wrath went to it. Hostile NPC (Taurocks) still count as any foe.
## RFC-053 053d (F373): the target the side committed to (FocusTask.committed) weighs AiTactics.commit_weight more, so the wizard's
## spells go where his creatures were sent, replan after replan; an enemy healer the side sees near that target (AiKillEstimate.
## healer_near; the target itself when it heals) weighs healer_weight more. Measured in f373_ai_finish before the change: each replan took the closest foe again.
## RFC-053 (deviation, wizAttack has no such test): a body the side's attack spells do not bring down (AiFutileTargets.is_futile:
## it regenerated between two casts) is passed over for AiTactics.spell_futile_forget_s. Measured in ai_easy_vs_normal seed 7: the
## Easy wizard threw a Rock at the same Taurock every ~19 s for five minutes (310 of 1500 each, back to full in between).
## Ref: wizAttack, shiny.d:3052-3071, 0x48d640 CheckAttack.

## The focus of the side (optional: without it nothing is committed).
@export var focus: FocusTask


func run(wizard: AiTrack, w3: Array[float], _record: AiRecord) -> void:
	var tactics := brain.play.tactics
	var best := 0.0
	var total := 0.0
	var best_track: AiTrack
	var thr := AiField.attack_reach(wizard.threat, tactics.attack_coefficient)
	var committed := focus.committed() if focus != null else null
	var committed_at := brain.perception.pos_of(committed) if committed != null else Vector3.ZERO
	for foe: AiTrack in brain.perception.bodies(3):
		if not AiWizardBrain.target_alive(foe) or brain.casting.futile.is_futile(foe):
			continue
		var distance := wizard.extrap_pos.distance_to(foe.extrap_pos)
		var able := AiBody.ability_ready(foe, brain.perception.mana_of(foe).x)
		var w := AiField.attack_weight(distance, thr, foe, able, tactics, foe.node is DoctorBody)
		if TargetRules.is_passive_npc(foe.node):
			w *= tactics.npc_passive_weight
		if committed != null:
			if foe == committed:
				w *= tactics.commit_weight
			## a healer by the committed target (the target itself when it heals) keeps it standing
			if AiKillEstimate.healer_near(brain.perception, foe, committed_at):
				w *= tactics.healer_weight
		w = AiField.f32(w)
		if w == 0.0:
			continue
		if best < w:
			best = w
			best_track = foe
		total = AiField.f32(total + w)
	if DebugLog.on(&"ai_attack"): print("ai_attack slot %d threat %.3f enemy_ratio %.3f best %s w %.3f total %.3f" % [brain.perception.slot, wizard.threat,
			brain.stance.enemy_ratio(), best_track.node.name if best_track != null and best_track.is_valid() else "-", best, total])
	if total == 0.0 or best_track == null:
		return
	var found := brain.eval.find_best(wizard, best_track, SpellType.AiPhase.ATTACK)
	if float(found["score"]) <= 0.0:
		return
	var entry := AiCastQueue.make(0, AiField.f32(AiField.safediv(best * w3[0], total)), found["target"], found["spell"], float(found["range"]), found["obj"])
	AiCastQueue.enqueue(wizard.cast_queue, entry)
