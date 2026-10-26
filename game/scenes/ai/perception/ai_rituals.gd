class_name AiRituals
extends RefCounted

## What the AI asks about the rituals (Convert and Desecrate) and the altars, with the rules the game itself uses (SacrificeSystem):
## a Desecrate under way against an altar or by the AI's own wizard, whether the wizard has a standing altar of his own, the enemy
## altar a Desecrate can reach. Static and read-only: it never starts a ritual.
## Ref: shiny.d:3079-3085 desecrationOngoing, 3096 and 2264 wizardSacrificing, 3100 closestShrine, 3358 closestEnemyAltar.

## The Desecrate reach when the match has no rules (MatchRules.desecrate_altar_range).
const DESECRATE_RANGE_FALLBACK := 75.0


## A Desecrate cast, carrier or ritual against the side of the altar `altar_track`.
static func desecration_against(system: SacrificeSystem, altar_track: AiTrack) -> bool:
	return system != null and altar_track != null and system.desecration_against(AiPerception.owner_slot_of(altar_track.node))


## The wizard of side `side` is desecrating (his `ucas` attachment).
static func own_desecration(system: SacrificeSystem, side: int) -> bool:
	return system != null and system.desecration_by(side)


## `wizard` has a standing altar of his own: where a Convert takes the creature.
static func has_home_altar(system: SacrificeSystem, side: int, wizard: Node3D) -> bool:
	return system != null and wizard != null and system.closest_own_site(side, wizard.global_position) != null


## The enemy altar within the Desecrate range of `wizard`, as the game defines it.
static func closest_enemy_altar_in_range(system: SacrificeSystem, side: int, wizard: Node3D) -> Node3D:
	if system == null or wizard == null:
		return null
	var rules: MatchRules = system.rules
	return system.closest_enemy_altar(side, wizard.global_position, rules.desecrate_altar_range if rules != null else DESECRATE_RANGE_FALLBACK)
