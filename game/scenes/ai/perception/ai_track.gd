class_name AiTrack
extends RefCounted

## What the AI knows of one body: what it is (`kind`, `relation`, `site`), what it can do (`fights`,
## `ready`, `free_fount`), whether its side has seen it, where it was, what it is worth, and the
## AI's own notes on it (last order, group, record, the wizard's cast queue). AiTrackFacts fills
## what it is and AiPerception keeps it up to date; a track never looks at the world by itself.
## Souls get a track of kind NONE (only the node and where it is).

## Same order as the original's node kinds.
enum Kind { NONE, WIZARD, CREATURE, MANAHOAR, STRUCTURE }
## The side of the body as this AI sees it. Also the index of the per-side lists (AiPerception,
## AiGroups, AiStance).
enum Relation { OWN, ALLY, NEUTRAL, ENEMY }
## What a structure is for the AI (NONE for bodies and souls).
enum Site { NONE, ALTAR, FOUNT, MANALITH, SHRINE }
## Why the AI knows the body: the first scan of the map, one of its own bodies appearing, the side's
## Vision saw it, or a soul.
enum Origin { SCAN, EVENT, SEEN, SOUL }

var kind := Kind.NONE
var relation := Relation.NEUTRAL
var site := Site.NONE
## Its side has seen it at some point: only own and seen bodies follow the real position.
var seen := false
## A body that fights: it has abilities or is not a pacifist (always, for a wizard).
var fights := false
## A Manahoar that can channel now, or a structure with nothing on top.
var ready := false
## A manafount nobody has built on.
var free_fount := false
var node: Node3D
## instance id of `node` (the key of AiPerception).
var id := 0
var age := 0
var age_seen := 0
var cur_pos := Vector3.ZERO
var extrap_pos := Vector3.ZERO
var prev_pos := Vector3.ZERO
var velocity := Vector3.ZERO
## In every difficulty the side does not know where the body is now, so its position stays
## where it was last seen (cur_pos); its health and mana are the ones of the moment it was last seen
## (seen_health, seen_mana: (current, maximum); zero if never seen).
var frozen := false
var seen_health := Vector2i.ZERO
var seen_mana := Vector2i.ZERO
## AiRater accumulator (5 floats) and its cached `rate`.
var acc := AiRater.new_acc()
var cached_rate := 0.0
## Threat of a wizard.
var threat := 0.0
var min_mana_cost := 0.0
var rerate_tick := 0
var status_tick := 0
var threat_tick := 0
var souls_snap_tick := 0
var souls_snap := 0
var mana_snap := 0
## Why the AI knows it.
var origin := Origin.SCAN
var group: AiGroup
var record: AiRecord
## Last order given by the brain, its target track and position.
var ord_state := AiCommandPort.AiOrder.NONE
var ord_target := 0
var ord_pos := Vector3.ZERO
## A body that went to a mana source because its mana fell to its minimum
## (CreatureBrain.auto_capture) stays by it until it holds AiTactics.mana_refill_ratio of its pool:
## without it the wizard left the altar the tick he had enough for one spell, cast it on the way and
## walked back (the back and forth on the same spot).
var refilling := false
## Wizard only: the creatures it may summon, rated against the field, and the cast queue.
var summons: Array = []
var spell_accs: Array = []
var cast_queue: Array = []
var spell_dirty := true
var next_replan := 0
var next_reissue := 0
var manahoar_spell: Resource
var shrine_spell: Resource
var convert_spell: Resource
var desecrate_spell: Resource


func is_body() -> bool:
	return kind == Kind.WIZARD or kind == Kind.CREATURE or kind == Kind.MANAHOAR


## A wizard (the status bits 2, 4, 8 and 0x20000 of the original only wizards had).
func is_wizard() -> bool:
	return kind == Kind.WIZARD


## An altar (the BLDG flag 0x200).
func is_altar() -> bool:
	return site == Site.ALTAR


## A structure the side's army can take down: a Manalith or a shrine (the original: MANALITH, or
## 0x40000 without ALTAR).
func is_tower() -> bool:
	return site == Site.MANALITH or site == Site.SHRINE


## A structure the capture task can aim at: all four kinds (the BLDG word & 0xc17 is never 0 for
## them).
func capturable() -> bool:
	return kind == Kind.STRUCTURE


## A body with no status at all: a creature that does not fight and a Manahoar that cannot channel
## now, or a fount with a structure on it. The groups and the records skip them.
func is_inert() -> bool:
	if kind == Kind.STRUCTURE:
		return not ready and site == Site.FOUNT
	return not fights and not ready and not is_wizard()


func is_valid() -> bool:
	return node != null and is_instance_valid(node) and not node.is_queued_for_deletion()


## A creature bound to a building by the Guardian spell.
func is_guardian_bound() -> bool:
	if (kind != Kind.CREATURE and kind != Kind.MANAHOAR) or not is_valid():
		return false
	var bond := GuardianBond.of(node)
	return bond != null and bond.is_bound()


## The key groups and ratings sort by.
func sort_key() -> float:
	return cached_rate if kind != Kind.NONE else 0.0


## A wizard's threat, a structure's rate.
func value_6c() -> float:
	if kind == Kind.WIZARD:
		return threat
	if kind == Kind.STRUCTURE:
		return cached_rate
	return 0.0
