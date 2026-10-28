class_name WizardStats
extends HBoxContainer

## The stats block of the wizard HUD: the soul count with the spinning soul, then the mana and
## health bars. It only feeds values to the bars and the label; frames, bars, font and the soul's
## spin live in the scene and in scenes/ui/theme.tres. It does not read the wizard (WizardHud does)
## and never takes the mouse.

## Values last shown (read by the flows).
var health_fraction := 0.0
var mana_fraction := 0.0
var souls_shown := 0


## Health and mana as 0…1 of their maximum, and the soul count.
func show_values(health: float, mana: float, souls: int) -> void:
	health_fraction = clampf(health, 0.0, 1.0)
	mana_fraction = clampf(mana, 0.0, 1.0)
	souls_shown = souls
	(%HealthBar as ProgressBar).value = health_fraction
	(%ManaBar as ProgressBar).value = mana_fraction
	(%Count as Label).text = str(souls)
