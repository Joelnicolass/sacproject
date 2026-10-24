class_name AiDifficulty
extends Resource

## How well the AI plays (RFC-024 §3.3 `AiDifficulty`, 024e). The original has no difficulty (shiny.d:380, 662: aggression fixed
## at 1.0); Normal is its numbers. Easy and Hard change only HOW FAST it thinks, how bold it is and what it knows: never what it has.
## RULES.md «IA»: no bonus of mana or souls and no cheat in any difficulty. A difficulty is another `.tres`
## (data/ai/difficulty_*.tres); it never changes while playing.

## The name of the difficulty in the UI (debug HUD now, the «Contra la IA» menu in 024f).
@export var display_name := "Normal"

@export_group("Reacción")
## Times the six slot periods of the profile (12/60/6/6/60/12 ticks). 2 = thinks half as often; 0.75 = faster. Each period is
## rounded down and never under 1 tick. The ages of the tracks count runs of k2, so the replans of the wizard scale with it.
@export_range(0.25, 4.0, 0.05) var period_scale := 1.0
## Takes the place of the profile's aggression (shiny.d:380, fixed 1.0 in the original). It scales the reach of Convert, the
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
## true: the AI reads the real state of the bodies it knows (position, health, mana), seen or not, as the original does
## (shiny.d:1710-1711 «cached live entPos», healthPair, startCasting on the entity). false: of an enemy, ally or neutral body its side
## does not see now (SideVision.is_visible_to) it uses only what it saw last: the position where it was (extrapolated one step),
## its health and mana of that moment; it cannot cast on it nor order its creatures after it (a human cannot click what he does not
## see). Deviation of the port in Normal (decision of the user, 2026-10-15); Hard = the original.
@export var perfect_information := false

@export_group("Sensatez (RFC-053)")
## The thresholds and weights of the AI's common sense (clear line, own splash, heal discipline, focus). Empty: tactics_normal.tres.
@export var tactics: AiTactics

@export_group("Recursos")
## RULES.md «IA»: the AI has no bonus of resources in any difficulty. Locked at 0 (RFC-024 §3.3) unless the user decides otherwise:
## any other value is refused when the resource is loaded. Nothing in the game reads it.
@export var resource_bonus := 0.0:
	set(value):
		if value != 0.0:
			push_warning("AiDifficulty: resource_bonus está bloqueado en 0 (RULES.md «IA»: sin bonificación de recursos)")
		resource_bonus = 0.0


## The profile this difficulty plays with: `base` itself when nothing changes (Normal), else a copy with the periods scaled and its
## aggression. The `.tres` of the profile is never changed.
func apply_to(base: AiProfile) -> AiProfile:
	if base == null:
		return null
	if period_scale == 1.0 and aggression == base.aggression:
		return base
	var out := base.duplicate() as AiProfile
	out.age_period_ticks = base.age_period_ticks if base.age_period_ticks > 0 else base.slot_periods[2]
	out.slot_periods = scaled_periods(base.slot_periods)
	out.aggression = aggression
	return out


func scaled_periods(periods: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for period in periods:
		out.append(maxi(1, int(floor(float(period) * period_scale + 0.0001))))
	return out


## The tactics this difficulty plays with (Normal's when it names none).
func tactics_or_normal() -> AiTactics:
	return AiTactics.or_normal(tactics)


## Physics ticks of `summon_interval_s` at `ticks_per_second`.
func summon_interval_ticks(ticks_per_second: int) -> int:
	return maxi(0, int(round(summon_interval_s * float(ticks_per_second))))


## Physics ticks of `request_delay_s` at `ticks_per_second`.
func delay_ticks(ticks_per_second: int) -> int:
	return maxi(0, int(round(request_delay_s * float(ticks_per_second))))
