class_name AiCaptureCasts
extends RefCounted

## What the wizard casts at the target of his capture record: Desecrate on an enemy altar (with the own creature of most souls
## brought next to him) or Manalith on a free fount. It does not choose the record (CaptureTask does) and it does not pay or
## check the cast (Casting does). Ref: shiny.d:3354-3382 (capture block of wizBrain), 3026-3050 pickGuardCreature,
## 3285-3301 castCachedInRange.

var perception: AiPerception
var port: AiCommandPort
var play: AiPlay
var casting: AiWizardCasting


func _init(p_perception: AiPerception, p_port: AiCommandPort, p_play: AiPlay, p_casting: AiWizardCasting) -> void:
	perception = p_perception
	port = p_port
	play = p_play
	casting = p_casting


## Every 8 ages, at the target of his capture record, Desecrate (an altar) or Manalith (a free fount). Returns 2 when it started the cast.
func run(wizard: AiTrack, record: AiRecord) -> int:
	var tn := record.target
	if tn == null or wizard.age < wizard.next_reissue:
		return 0
	var reissue := play.ages_for(play.tactics.wizard_reissue_s)
	wizard.next_reissue = wizard.age + reissue
	if tn.is_altar():
		## The desecrate path: an enemy altar not under ritual, the creature with most souls brought next to the wizard, and
		## the altar being the closest enemy one in range (the game's closestEnemyAltar).
		if wizard.desecrate_spell != null and tn.relation == AiTrack.Relation.ENEMY and not perception.desecration_against(tn):
			var guard := pick_guard_creature(tn)
			if guard != null and perception.closest_enemy_altar_in_range() == tn.node:
				var spell: SpellType = wizard.desecrate_spell
				var radius := AiField.f32(spell.cast_range_m * play.tactics.desecrate_range_factor)
				if port.orders.order_target_radius(guard, AiCommandPort.AiOrder.GUARD, wizard, radius) != 0:
					if casting.enqueue_forced_execute(wizard, guard, spell, spell.cast_range_m, null) != 0:
						wizard.next_reissue += 7 * reissue
						return 2
	elif tn.capturable() and tn.free_fount:
		if cast_cached_in_range(wizard, tn) != 0:
			return 2
	return 0


## Of the own creatures (not the wizard) the one that weighs most (1 within guard_pick_near_m of the target, falling linearly to 0 at
## guard_pick_far_m; the scale is 1/(far - near) rounded to float32, as the original's constant 0.00027700831)
## times its souls; a strict argmax from 0, so a creature of 0 souls is never picked. Deviation: the game's own test
## `sacrifice_status` (alive, free, not held, a Captive) filters the candidates first, so the AI never asks Desecrate for a creature
## that would answer «Blanco inválido» (sacengine tests the mode after picking). A creature bound by the Guardian spell is skipped.
## Ref: shiny.d:3026-3050 (0x485700), 3032 isGuardianEnt.
func pick_guard_creature(target: AiTrack) -> AiTrack:
	var best := 0.0
	var best_track: AiTrack
	var system := perception.sacrifice()
	var near := play.tactics.crowd.guard_pick_near_m
	var far := play.tactics.crowd.guard_pick_far_m
	var scale := AiField.f32(1.0 / (far - near))
	for c: AiTrack in perception.bodies(0):
		if c.kind == AiTrack.Kind.WIZARD or not c.is_valid():
			continue
		## a creature bound to a building by the Guardian spell is never the victim
		if c.is_guardian_bound():
			continue
		if system != null and not system.sacrifice_status(perception.slot, c.node).is_empty():
			continue
		var worth := AiGroups.souls_pair(c).x
		var d := c.extrap_pos.distance_to(target.cur_pos)
		var w := 0.0
		if d <= near:
			w = 1.0
		elif d < far:
			w = (far - d) * scale
		var v := w * float(worth)
		if best < v:
			best = v
			best_track = c
	if best_track != null and best_track.group != null:
		(best_track.group as AiGroup).members.erase(best_track)
		best_track.group = null
	return best_track


## The Manalith spell, forced, when the wizard is within range * sqrt(build_range_slack) * build_reach_factor of the fount and the
## threat is under build_threat_cap. The fount must still be free (canCastSpellOn's onlyManafounts reads it live). Ref: shiny.d:3285-3301 (0x48dce0).
func cast_cached_in_range(wizard: AiTrack, fount: AiTrack) -> int:
	var shrine: SpellType = wizard.shrine_spell
	var tactics := play.tactics
	if shrine == null or wizard.threat >= tactics.build_threat_cap:
		return 0
	if not fount.is_valid() or not (fount.node as ManafountBody).is_free():
		return 0
	var r := float(shrine.cast_range_m)
	r = r * r * tactics.build_range_slack * (tactics.build_reach_factor * tactics.build_reach_factor)
	if wizard.cur_pos.distance_squared_to(fount.cur_pos) > r:
		return 0
	return casting.enqueue_forced_execute(wizard, fount, shrine, shrine.cast_range_m, null)
