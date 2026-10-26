class_name AiSelfArea
extends RefCounted

## What a burst around the wizard himself is worth (Halo of Earth): what the known enemy bodies inside the spell's reach
## (`effect_range_m`) of him are worth together, once they are at least `self_area_min_foes`; nothing with fewer. It reads where the
## side believes they are (AiTrack.cur_pos). It never casts: the attack phase queues it on him. Static. AI's own design (055f f5).


static func rate(spell: SpellType, caster: AiTrack, foes: Array, tactics: AiTactics) -> float:
	var count := 0
	var worth := 0.0
	for foe: AiTrack in foes:
		if not foe.is_body() or not AiWizardBrain.target_alive(foe):
			continue
		if caster.cur_pos.distance_to(foe.cur_pos) <= spell.effect_range_m:
			count += 1
			worth += foe.sort_key()
	return AiField.f32(worth) if count >= tactics.self_area_min_foes else 0.0
