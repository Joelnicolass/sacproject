class_name AiTactics
extends Resource

## How an AI wizard plays one difficulty, phase by phase, in seconds and meters: whom he attacks and from how far, when he heals or
## wards, when he summons, converts, builds or takes souls, and how often he replans. `crowd` says how his creatures move and
## `senses` how often the side looks again at what it knows; both are embedded in the same file. One file per difficulty
## (data/ai/tactics_*.tres); a seat can bring its own (AiSeat.tactics). Nothing here gives the AI more than a human has, and it is
## never changed while playing. The numbers without a mark are the original's.
## Ref: sacengine shiny.d, «según [S]»

const NORMAL := "res://data/ai/tactics_normal.tres"

## Groups, records, guards, mana and focus of the creatures.
@export var crowd: AiCrowdTactics
## How often the side looks again at a body, the wizard's threat.
@export var senses: AiSenses

@export_group("Ritmo del mago")
## Seconds between two replans of the wizard and between two re-issues of an order (16 and 8 ages at Normal).
@export_range(0.0, 60.0, 0.0001, "suffix:s") var wizard_replan_s := 1.6
@export_range(0.0, 60.0, 0.0001, "suffix:s") var wizard_reissue_s := 0.8
## A ghost waits while one of his Manahoars is within this (it channels him back).
@export var ghost_wait_m := 256.0
## On guard of a body the wizard stops this far from it.
@export var wizard_stop_m := 10.0

@export_group("Ataque")
## He looks for a foe within (1 - threat) * this (the beta used 180).
@export var attack_coefficient := 280.0
## A foe that is not a wizard, one with no ready ability and a Sac Doctor weigh this much more (AiField keeps them as constants).
@export var weight_passive := 0.5
@export var weight_no_ability := 0.3333333432674408
@export var weight_sac_doctor := 10.0
## A spell is rated only inside range * sqrt(1.4): distance² times this over range² rejects it; under near_distance_sq it counts as 0.
@export var range_distance_scale := 0.7142857313156128
@export var near_distance_sq := 1600.0
## Weight of a passive NPC among the targets. 0: never (RFC-053 053b).
@export_range(0.0, 1.0, 0.05) var npc_passive_weight := 0.0
## Weight of an enemy that heals (053d).
@export_range(0.0, 10.0, 0.1) var healer_weight := 2.0
## Weight of the target the side committed to, and seconds the side keeps it (053d).
@export_range(0.0, 10.0, 0.1) var commit_weight := 1.5
@export_range(0.0, 60.0, 0.5) var commit_hold_s := 6.0
## A body the side's attack spells would not bring down in this many casts (it regenerates between them) is banned as a target for
## spell_futile_forget_s. 0 s: never banned (the original).
@export_range(1, 20) var spell_kill_max_casts := 3
@export_range(0.0, 120.0, 1.0) var spell_futile_forget_s := 30.0
## A control spell (Freeze, Vines, Rings of Fire, Slime) is worth the target's rating times min(1, seconds it lasts / this).
@export_range(1.0, 60.0, 1.0) var disable_ref_s := 10.0
## A burst around himself (Halo) is worth casting with at least this many known enemies inside its reach (055f f5).
@export_range(1, 20) var self_area_min_foes := 2

@export_group("Tiro limpio y daño propio (053b)")
## A projectile or area spell is cast only with a clear line; without it he walks this fraction of the way, then tries again.
@export var los_check := true
@export_range(0.05, 1.0, 0.05) var los_retry_factor := 0.5
## A splash spell is not cast if the burst would take more than this fraction of the maximum health of an own body (him included
## when own_splash_counts_wizard).
@export_range(0.0, 1.0, 0.01) var own_splash_max_ratio := 0.1
@export var own_splash_counts_wizard := true

@export_group("Apoyo")
## Heal goes only to a body at or under this fraction of its health that misses at least heal_min_missing (053c).
@export_range(0.0, 1.0, 0.05) var heal_below_ratio := 0.6
@export_range(0.0, 2000.0, 10.0) var heal_min_missing := 100.0
## He wards himself when at least guard_min_foes known enemies stand within guard_threat_m (061b).
@export_range(0.0, 100.0, 1.0) var guard_threat_m := 25.0
@export_range(1, 10) var guard_min_foes := 2
## A heal on an area (Rainbow, Healing Aura) goes where the own bodies inside it miss at least this much health in all (055f f5).
@export_range(0.0, 5000.0, 10.0) var heal_area_min_missing := 300.0
## He jumps to an own building far away (Teleport) when his threat is at least this (0: calm, 1: overrun) (055f f5). 0.5: the
## enemy near him weighs as much as his whole side near him (8 Troggs on a wizard with 2 creatures measure about that).
@export_range(0.0, 1.0, 0.05) var escape_threat := 0.5

@export_group("Convocar")
## The emergency Manahoar is considered when a random draw is at least threat * this.
@export var emergency_threat_factor := 1.2999999523162842
## Creatures are summoned only under this threat.
@export var summon_threat_cap := 0.6
## The Manahoar is forced when none is ready or the mana deficit per Manalith and ready one is over this, while ready < souls / divisor.
@export var emergency_mana_ratio := 1400.0
@export var ready_divisor := 2
## How much the hostile NPC near him count in the threat that stops his summons: 1 the original, 0 a village camp never stops him.
@export_range(0.0, 1.0, 0.05) var npc_summon_threat_weight := 0.0
## The summon pool (max mana x Manaliths) counts at least this many Manaliths. 0: the original (none, nothing summoned).
@export_range(0, 4) var summon_min_manaliths := 1

@export_group("Convertir")
## Convert is looked for within (1 - own share of souls) * (1 - threat) * aggression * this, and queued at this factor of its weight.
@export var convert_reach_m := 500.0
@export var convert_score_factor := 0.8999999761581421

@export_group("Captura")
## He builds a Manalith only under this threat (the beta 0.6), within range² * build_range_slack * build_reach_factor² of the fount.
@export var build_threat_cap := 0.9
@export var build_range_slack := 1.399999976158142
@export var build_reach_factor := 5.0
## Desecrate brings the guard creature within this factor of the spell's range.
@export var desecrate_range_factor := 0.8999999761581421

@export_group("Almas")
## He takes souls by touching them within (1 - threat) * scale + base (the beta 80 and 60).
@export var soul_reach_scale := 100.0
@export var soul_reach_base := 80.0
## Deviation: while he walks to a soul he keeps looking for it within this times the reach (the way can first lead away). 1: the original.
@export var soul_keep_factor := 1.25
## A soul farther than this he would rather send a spell for (Soul Wind, Soul Mole) than walk to; nearer, he walks (055f f5).
@export_range(0.0, 200.0, 1.0, "suffix:m") var soul_send_min_m := 40.0


## `tactics` or, when null, the Normal one.
static func or_normal(tactics: AiTactics) -> AiTactics:
	return tactics if tactics != null else load(NORMAL) as AiTactics
