class_name AiDifficulty
extends Resource

## How well the AI plays. The original has no difficulty (aggression fixed
## at 1.0); Normal is its numbers. Easy and Hard change only HOW FAST it thinks, how bold it is and what it knows: never what it has.
## RULES.md «IA»: no bonus of mana or souls and no cheat in any difficulty. A difficulty is another `.tres`
## (data/ai/difficulty_*.tres); it never changes while playing.
## Ref: RFC-024 §3.3 `AiDifficulty`, 024e; shiny.d:380, 662.

## The name of the difficulty in the UI (debug HUD now, the «Contra la IA» menu in 024f).
@export var display_name := "Normal"

@export_group("Reacción")
## Times the six periods of the side's clock (AiClock: 12/60/6/6/60/12 ticks at Normal). 2 = thinks half as often; 0.75 = faster.
## Each period is rounded down and never under 1 tick. The ages of the tracks count runs of the perception job, so the replans of
## the wizard scale with it.
@export_range(0.25, 4.0, 0.05) var period_scale := 1.0
## How bold the side plays (AiPlay.aggression; fixed 1.0 in the original, shiny.d:380). It scales the reach of Convert, the
## weights of attacking and the claims of the capture task.
@export_range(0.0, 1.0, 0.05) var aggression := 1.0
## Seconds between the decision and the request that leaves the port (a cast, a summon, an order, a walk): a human's reaction.
## While a cast waits the wizard counts as busy (he asks for nothing else), and the request goes out only if it still could be paid.
@export_range(0.0, 2.0, 0.05) var request_delay_s := 0.0

@export_group("Convocatorias")
## Adenda 1.3: a limit the AI puts on itself, not a rule of the game. Minimum seconds between two summons it decides (the
## Manahoar included). 0 = none (Normal, Hard: the original). Summons are bound by mana, not by how often the AI thinks, so the
## slower periods of Easy alone did not slow them (measured in 024e: Easy summoned 124 % of Normal).
@export_range(0.0, 120.0, 1.0) var summon_interval_s := 0.0
## Adenda 1.3: the fraction of the wizard's maximum mana the AI keeps and never spends on a creature (the Manahoar, which brings
## mana, is not held back). 0 = none (Normal, Hard). Nothing is taken from the wizard: he only chooses not to spend it.
@export_range(0.0, 0.9, 0.05) var mana_reserve := 0.0

@export_group("Información")
## What the AI may know of the bodies its side does not see now. No difficulty reads the real health or mana of one of them (RULES.md
## «IA»: no cheat in any difficulty); what changes is the position.
enum Knowledge {
	## Only what the side's Visions see. Of a body it does not see it keeps what it saw last: the place where it was (one step of
	## its last velocity ahead), its health and mana of that moment; it cannot cast on it nor order its creatures after it.
	SIGHT,
	## SIGHT plus what a human reads on the minimap: the position (never health nor mana) of the bodies within
	## `tactics.senses.map_sight_m` of the own wizard, and of every enemy wizard (the arrow at the edge of the minimap).
	SIGHT_AND_MAP,
}
@export var knowledge: Knowledge = Knowledge.SIGHT

@export_group("Sensatez (RFC-053)")
## How the wizard and his creatures play this difficulty (data/ai/tactics_*.tres, with crowd and senses). Empty: tactics_normal.tres.
@export var tactics: AiTactics

@export_group("Recursos")
## RULES.md «IA»: the AI has no bonus of resources in any difficulty. Locked at 0 (RFC-024 §3.3) unless the user decides otherwise:
## any other value is refused when the resource is loaded. Nothing in the game reads it.
@export var resource_bonus := 0.0:
	set(value):
		if value != 0.0:
			push_warning("AiDifficulty: resource_bonus está bloqueado en 0 (RULES.md «IA»: sin bonificación de recursos)")
		resource_bonus = 0.0


## The tactics this difficulty plays with (Normal's when it names none).
func tactics_or_normal() -> AiTactics:
	return AiTactics.or_normal(tactics)


## Physics ticks of `summon_interval_s` at `ticks_per_second`.
func summon_interval_ticks(ticks_per_second: int) -> int:
	return maxi(0, int(round(summon_interval_s * float(ticks_per_second))))


## Physics ticks of `request_delay_s` at `ticks_per_second`.
func delay_ticks(ticks_per_second: int) -> int:
	return maxi(0, int(round(request_delay_s * float(ticks_per_second))))
