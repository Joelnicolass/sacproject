class_name AttackPhase
extends AiPhase

## wizAttack (shiny.d:3052-3071, 0x48d640 CheckAttack): among the enemy bodies the side knows (creatures, wizards,
## the NPC of the villages) within (1 - threat) * 280 m, the one of most weight (1 within 10 m, falling linearly to 0;
## x0.5 if it is not aggressive, x1/3 if it has no ready ability, x10 a Sac Doctor) is the target, and the book's attack
## with the best score against it is queued with the score `best * w3[0] / total`.
## It uses what the AI KNOWS: an enemy it has not seen stays where it was when taken in.


func run(wizard: AiTrack, w3: Array[float], _record: AiRecord) -> void:
	var profile := brain.profile
	var best := 0.0
	var total := 0.0
	var best_track: AiTrack
	var thr := AiField.attack_reach(wizard.threat, profile.attack_coefficient)
	for foe: AiTrack in brain.perception.bodies(3):
		if not AiWizardBrain.target_alive(foe):
			continue
		var distance := wizard.extrap_pos.distance_to(foe.extrap_pos)
		var w := AiField.attack_weight(distance, thr, foe.status, false)
		w = AiField.f32(w)
		if w == 0.0:
			continue
		if best < w:
			best = w
			best_track = foe
		total = AiField.f32(total + w)
	if total == 0.0 or best_track == null:
		return
	var found := brain.eval.find_best(wizard, best_track, AiSpellEval.ATTACK_MASK)
	if float(found["score"]) <= 0.0:
		return
	var entry := AiCastQueue.make(0, AiField.f32(AiField.safediv(best * w3[0], total)), best_track, found["spell"], float(found["range"]), found["obj"])
	AiCastQueue.enqueue(wizard.cast_queue, entry)
