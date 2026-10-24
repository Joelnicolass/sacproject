class_name RockFormState
extends UnitState

## ROCK_FORM, the Earthfling's Rockform (ActiveAbility): still, regenerating, 5 % damage and hidden from enemy AI.

## sacengine dealDamage: damage x0.05 in rockForm (state.d:8964).
const ROCK_FORM_DAMAGE := 0.05


func present(_animate: bool) -> void:
	_show(true)


func exit() -> void:
	_show(false)
	super.exit()


func regenerates() -> bool:
	return true


func _show(on: bool) -> void:
	(body.get_node("ActiveAbility") as ActiveAbility).show_rock_form(on)
	body.get_node("Health").set("damage_factor", ROCK_FORM_DAMAGE if on else 1.0)
