class_name SupportPhase
extends AiPhase

## wizSupport (shiny.d:3073-3087, 0x48d7c0): among the own bodies (creatures, Manahoars, the wizard himself, but not a ghost) the one
## the book's support spell (Heal, Speedup) rates highest; the entry is queued with the score `best * w3[1] / total`, where `total`
## is the sum of what every body rates (so with many bodies that need it, none stands out). The ratings are in AiSpellEval.


func run(wizard: AiTrack, w3: Array[float], _record: AiRecord) -> void:
	var best := 0.0
	var total := 0.0
	var best_track: AiTrack
	var best_found: Dictionary = {}
	for own: AiTrack in brain.perception.bodies(0):
		if not AiWizardBrain.target_alive(own):
			continue
		if own.kind == AiTrack.Kind.WIZARD and (own.node as WizardBody).is_ghost():
			continue
		var found := brain.eval.find_best(wizard, own, SpellType.AiPhase.SUPPORT)
		var s := float(found["score"])
		if best < s:
			best = s
			best_track = own
			best_found = found
		total = AiField.f32(total + s)
	if total == 0.0 or best == 0.0 or best_track == null:
		return
	var entry := AiCastQueue.make(0, AiField.f32(AiField.safediv(best * w3[1], total)), best_track, best_found["spell"], float(best_found["range"]), best_found["obj"])
	AiCastQueue.enqueue(wizard.cast_queue, entry)
