class_name SupportPhase
extends AiPhase

## What the wizard helps: among the own bodies (creatures, Manahoars, the wizard himself, but not a
## ghost) the one the book's support spell (Heal, Speedup, a heal on an area, Guardian) rates
## highest; the entry is queued with the score `best * w3[1] / total`, where `total` is the sum of
## what every body rates (so with many bodies that need it, none stands out). Looking at the wizard
## himself also weighs what he does for his side from where he stands: raise a corpse, fetch a soul,
## escape; the entry then aims at that soul or building (AiSpellEval.find_best). The ratings are in
## AiSpellEval and AiSpellUses.


func run(wizard: AiTrack, w3: Array[float], _record: AiRecord) -> void:
	var best := 0.0
	var total := 0.0
	var best_track: AiTrack
	var best_found: Dictionary = {}
	for own: AiTrack in brain.perception.bodies(AiTrack.Relation.OWN):
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
	var entry := AiCastQueue.make(
		false,
		AiField.f32(AiField.safediv(best * w3[1], total)),
		best_found["target"],
		best_found["spell"],
		float(best_found["range"]),
		best_found["obj"]
	)
	AiCastQueue.enqueue(wizard.cast_queue, entry)
