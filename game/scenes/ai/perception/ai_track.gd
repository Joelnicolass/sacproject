class_name AiTrack
extends RefCounted

## What the AI knows of one body: the `AINode` of shiny.d:78-132 as a RefCounted (RFC-024 §3.1 `AiTrack`). Kinds
## follow shiny.d:46 (`NodeKind`): a wizard, a creature (`t4o`), a Manahoar, a structure. The relation flags are
## shiny.d:748 (`relationFlag`: own 1, ally 2, enemy 4, neutral 0) and the category is `categoryFromFlags` (shiny.d:750-753).
## Souls are not tracked in 024c (the AI does not collect them yet, RFC-024 §6 024d).

enum Kind { NONE, WIZ, CRE, MAHO, STR }

const OWN := 1
const ALLY := 2
const ENEMY := 4
## Seen by the side at some point: updateBase only follows own and seen bodies (shiny.d:1025).
const SEEN := 0x80
const BODY := 0x10
const STRUCTURE := 0x20
const WIZARD := 0x100
## A structure with the BLDG flag 1 (the altar): shiny.d:930 `flags |= 0x300`; with 0xc17: 0x100 (931).
const ALTAR := 0x200
const CAPTURABLE := 0x100

## status bits (shiny.d:884-1100).
const ACTIVE := 0x1
const WIZARD_STATUS := 0x2000e
const READY := 0x1000
const UNBUILT := 0x8000
const MANALITH := 0x4000

var kind := Kind.NONE
var node: Node3D
## instance id of `node` (the key of AiPerception).
var id := 0
var flags := 0
var status := 0
var age := 0
var age_seen := 0
var cur_pos := Vector3.ZERO
var extrap_pos := Vector3.ZERO
var prev_pos := Vector3.ZERO
var velocity := Vector3.ZERO
## 024e, without perfect information (Easy, Normal): the body is not seen by the side now, so its position stays where it was last
## seen (cur_pos) and its health and mana are the ones of that moment (seen_health, seen_mana: (current, maximum)).
var frozen := false
var seen_health := Vector2i.ZERO
var seen_mana := Vector2i.ZERO
## AiRater accumulator (5 floats) and its cached `rate` (the sort key, shiny.d:1432-1437).
var acc := AiRater.new_acc()
var cached_rate := 0.0
## Threat of a wizard (shiny.d:1061-1085).
var threat := 0.0
var min_mana_cost := 0.0
var rerate_tick := 0
var status_tick := 0
var threat_tick := 0
var souls_snap_tick := 0
var souls_snap := 0
var mana_snap := 0
## Why the AI knows it: «scan» (scanGlobal, t = 0), «event» (its own bodies), «seen» (the side's Vision saw it).
var origin := &"scan"
var group: AiGroup
var record: AiRecord
## Last order given by the brain (shiny.d:2393-2420 orderIfChanged): state, target track, position.
var ord_state := 0
var ord_target := 0
var ord_pos := Vector3.ZERO
## A body that went to a mana source because its mana fell to its minimum (CreatureBrain.auto_capture) stays by it until it holds
## AiTactics.mana_refill_ratio of its pool: without it the wizard left the altar the tick he had enough for one spell, cast it on the
## way and walked back (the back and forth on the same spot).
var refilling := false
## Wizard only: the creatures it may summon, rated against the field (wizSpellRebuild, shiny.d:2610), and the cast queue.
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


## categoryFromFlags (shiny.d:750-753): 0 own, 1 ally, 2 neutral, 3 enemy.
func category() -> int:
	if flags & OWN:
		return 0
	if flags & ALLY:
		return 1
	return 3 if (flags & ENEMY) else 2


func is_body() -> bool:
	return kind == Kind.WIZ or kind == Kind.CRE or kind == Kind.MAHO


func is_valid() -> bool:
	return node != null and is_instance_valid(node) and not node.is_queued_for_deletion()


## node vtbl[7] (shiny.d:1432-1437): the key groups and ratings sort by.
## isGuardianEnt (shiny.d:2995): a creature bound to a building by the Guardian spell.
func is_guardian_bound() -> bool:
	if (kind != Kind.CRE and kind != Kind.MAHO) or not is_valid():
		return false
	var bond := GuardianBond.of(node)
	return bond != null and bond.is_bound()


func sort_key() -> float:
	return cached_rate if kind != Kind.NONE else 0.0


## nodeValue6c (shiny.d:1439-1447): a wizard's threat, a structure's rate.
func value_6c() -> float:
	if kind == Kind.WIZ:
		return threat
	if kind == Kind.STR:
		return cached_rate
	return 0.0
