class_name AiTactics
extends Resource

## The common-sense rules of the AI's wizard (RFC-053 §7, F371-F373): thresholds and weights that the original does not have but that
## keep it from hurting itself, healing what is healthy and spreading its fire. One `.tres` per difficulty (data/ai/tactics_*.tres),
## named by AiDifficulty.tactics; none = tactics_normal.tres. Nothing here gives the AI more than a human has: they only choose
## what it does with what its side knows. Never changed while playing.

const NORMAL := "res://data/ai/tactics_normal.tres"

@export_group("Curación (053c)")
## Heal only goes to a body at or under this fraction of its health.
@export_range(0.0, 1.0, 0.05) var heal_below_ratio := 0.6
## Heal only goes to a body that misses at least this much health.
@export_range(0.0, 2000.0, 10.0) var heal_min_missing := 100.0

@export_group("Tiro limpio (053b)")
## A projectile or area spell is cast only with a clear line (AiLineOfFire); without it the wizard walks closer (shiny.d:3262).
@export var los_check := true
## Without a clear line the wizard walks this fraction of the distance to the target, then tries again (0.5: halfway).
@export_range(0.05, 1.0, 0.05) var los_retry_factor := 0.5

@export_group("Daño propio (053b)")
## A splash spell is not cast if the burst would take more than this fraction of the maximum health of any own body.
@export_range(0.0, 1.0, 0.01) var own_splash_max_ratio := 0.1
## The wizard himself counts among the own bodies of that test.
@export var own_splash_counts_wizard := true

@export_group("Pesos de blanco (053b, 053d)")
## Weight of a passive NPC (aggressiveness 0 on an NPC slot) among the targets of the attack spells. 0: never.
@export_range(0.0, 1.0, 0.05) var npc_passive_weight := 0.0
## Weight of an enemy that heals (053d).
@export_range(0.0, 10.0, 0.1) var healer_weight := 2.0
## Weight of the target the side committed to (053d).
@export_range(0.0, 10.0, 0.1) var commit_weight := 1.5
## Seconds the side keeps a commitment (053d).
@export_range(0.0, 60.0, 0.5) var commit_hold_s := 6.0

@export_group("Foco (053d)")
## A target is focused only if the side can kill it in this many seconds.
@export_range(0.0, 120.0, 1.0) var focus_kill_window_s := 20.0
## A target is focused only if the local strength is over this ratio.
@export_range(0.0, 10.0, 0.1) var focus_power_ratio := 1.2
## Candidates: known enemies within this distance of an own group.
@export_range(0.0, 500.0, 5.0) var focus_radius_m := 60.0
## Creatures a focus claims at most.
@export_range(0, 32) var focus_max_members := 6
## What an enemy wizard is worth among the candidates of a focus, in souls (a creature is worth its souls): killing him stops his casts.
@export_range(0.0, 20.0, 0.5) var focus_wizard_worth := 4.0


## `tactics` or, when null, the Normal one.
static func or_normal(tactics: AiTactics) -> AiTactics:
	return tactics if tactics != null else load(NORMAL) as AiTactics
