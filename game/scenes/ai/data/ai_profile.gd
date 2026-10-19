class_name AiProfile
extends Resource

## The numbers of the original AI, commercial version (`Sacrifice.exe`): every `beta*` switch of
## sacengine `source/bots/shiny.d` off (shiny.d:381-412). Each comment gives the `shiny.d` line and the mark of the
## source: «según [S]» = what sacengine's author wrote after reading the executable (his comments cite the retail
## address, e.g. `retail 0x4901a0`); «verificado [O]» would be a check of mine against Sacrifice.exe with REA, and
## none was made in 024c, so no number carries it. These numbers are Normal; a difficulty (AiDifficulty, 024e) scales the
## periods and sets the aggression on a copy. The `.tres` is never changed while playing. 024e: one profile per god (data/ai/profile_<god>.tres) with the same numbers,
## since the original has no personality: the god changes only the book of the wizard. The difficulty (AiDifficulty) is apart.

const DIR := "res://data/ai"

## The god this profile is for (empty: the original, every god).
@export var god: StringName = &""

@export_group("Reloj (6 ranuras)")
## Ticks between runs of the slots k0..k5: updateStatus, updateStance, updateNtts, updateGroups, updateReplan,
## updateTasks. Según [S] shiny.d:468 (`periods=[12,60,6,6,60,12]`).
@export var slot_periods: PackedInt32Array = PackedInt32Array([12, 60, 6, 6, 60, 12])
## Según [S] shiny.d:380 and 662: fixed 1.0, no code changes it. The original has no difficulty.
@export_range(0.0, 1.0) var aggression := 1.0

@export_group("Percepción y nodos")
## Ages count RUNS of updateNtts, not ticks: `run(...,1)` hands dTicks = 1 to every slot (shiny.d:459, 1289-1297), so a body's
## age goes up by 1 every 6 ticks (slot k2). A creature is rated again every 16 age (96 ticks, shiny.d:1044), a structure
## every 32 (shiny.d:1089); the mana and status of a body every 8 (1053, 1095); a wizard's soul count every 32 (1080).
## Según [S].
@export var rerate_ticks := 16
@export var status_ticks := 8
@export var souls_snapshot_ticks := 32
## Threat of a wizard: every 8 age (48 ticks), the influence of the groups within 10..280 m of it (shiny.d:1065-1072). Según [S].
@export var threat_ticks := 8
@export var threat_near := 10.0
@export var threat_far := 280.0

@export_group("Grupos y registros")
## canAccept (shiny.d:1702-1710): a group of n takes a body within 30*min(1+0.1n, 1.8) m of its center. Según [S].
@export var group_radius_m := 30.0
@export var group_growth := 0.1
@export var group_cap := 1.8
## A record whose members are all within this of its center lets each member think by itself (recordUpdate
## shiny.d:3433: dx²+dy² <= 10000). Según [S].
@export var record_near_m := 100.0
## Followers of a record's leader hold where they stand once they are within this of him (orderPosRadius radius, shiny.d:3419; the
## original passes 0). Deviation of the port: its bodies steer around each other (BodyAvoidance), so followers pressed onto the
## wizard's own spot shoved him off his altar (measured: 70 m in 3 min). 8 m keeps them around him.
@export var follow_radius_m := 8.0
## A creature (or the wizard) on guard of a body or structure stops this far from it and fights from there: the retreat order of the
## engine arrives at the target's radius + 10 m (state.d:13608 `retreatDistance`, shiny.d:2376). The port's `guard` order puts each
## creature in a tight formation 2-3 m from the target, where they stacked on the wizard and shoved him off his Manalith (measured).
@export var retreat_hold_m := 10.0
## Time between the wizard's replans and the re-issue of an order, in age (16 age = 96 ticks = 1.6 s; shiny.d:3328, 3356). Según [S].
@export var wizard_replan_ticks := 16
@export var wizard_reissue_ticks := 8

@export_group("Hechizos y convocatorias")
## wizAttack reach: (1 - threat) * 280 m (shiny.d:3058, retail 0x4901a0; the beta uses 180). Según [S].
@export var attack_coefficient := 280.0
## Bodies that cost the spell scan more or less (shiny.d:3070-3072): not aggressive x0.5, no ready ability x1/3,
## Sac Doctor x10. Según [S].
@export var weight_passive := 0.5
@export var weight_no_ability := 0.3333333432674408
@export var weight_sac_doctor := 10.0
## A spell is rated only inside range*sqrt(1.4): distSq*0.7142857 above range² rejects it, and under 1600 counts as 0
## (shiny.d:2928-2934). Según [S].
@export var range_distance_scale := 0.7142857313156128
@export var near_distance_sq := 1600.0
## wizSacrifice (shiny.d:3115-3172): the emergency Manahoar is considered when rand >= threat * 1.3 (3124);
## creatures are summoned only when threat < 0.6 (3139); the Manahoar is forced if no one is ready or mana deficit per
## manalith and ready one exceeds 1400 (3131), and while ready < souls/2 (3127, retail; the beta uses /4). Según [S].
@export var emergency_threat_factor := 1.2999999523162842
@export var summon_threat_cap := 0.6
@export var emergency_mana_ratio := 1400.0
@export var ready_divisor := 2

@export_group("Captura y almas (024d)")
## castCachedInRange (shiny.d:3295): the wizard builds a Manalith only while his threat is under 0.9 (retail 0x490850; the beta 0.6). Según [S].
@export var build_threat_cap := 0.9
## Souls he takes by touching them: (1 - threat) * 100 + 80 m (shiny.d:3330-3337, retail 0x490b20; the beta 80 and 60). Según [S].
@export var soul_reach_scale := 100.0
@export var soul_reach_base := 80.0
## Deviation of the port (024d fix), not «según [S]»: while the wizard walks to a soul (ostate 0x22) he keeps looking for it within
## this times the reach. The way to a soul can first lead away from it (around a block of the grid), and at the edge of the reach
## the wizard found the soul, walked, lost it, walked back to his cast: forever (ai_vs_trivial seed 3). 1 = the original rule.
@export var soul_keep_factor := 1.25
## wizRetreat (shiny.d:3098): Convert is looked for within (1 - own share of souls) * (1 - threat) * aggression * 500 m. Según [S].
@export var convert_reach_m := 500.0
## Convert and Desecrate are queued with these factors of the weight (shiny.d:3113, 3366). Según [S].
@export var convert_score_factor := 0.8999999761581421
@export var desecrate_range_factor := 0.8999999761581421
## A Manahoar or a mana building is looked for within this of a body that needs mana (autoCapture, shiny.d:2552 `3620.0f`). Según [S].
@export var mana_seek_m := 3620.0
## A capture record asks a creature to think from this far (orderInteract radius: (1 - value) * 160 m, shiny.d:2565). Según [S].
@export var interact_reach_m := 160.0


## The profile of a god (the `ai_profile` of data/gods/<god>.tres), or the original when the god has none.
static func for_god(god_name: StringName) -> AiProfile:
	var type := GameCatalog.shared().god(String(god_name))
	if type != null and type.ai_profile != null:
		return type.ai_profile
	return load(DIR.path_join("profile_original.tres")) as AiProfile
