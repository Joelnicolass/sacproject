@tool
class_name WardAction
extends SpellAction

## A spell the wizard casts on himself that switches on one of his wards (Skin of Stone, Air Shield, Ethereal Form, Fireform,
## Protective Swarm): the key starts the cast, no click. When the casting time ends the Ward of that spell runs for the spell's
## duration. One scene for all of them; the numbers are the SpellType's and the Ward's. It does not scale damage (Wards) nor
## push or burn anyone (BodyAura).
## Ref: sacengine skinOfStone, airShield, etherealForm, fireform, protectiveSwarm (state.d:10591-10686).


## Funds first, then the ward: missing = NOT_IMPLEMENTED, already on = BAD_TARGET (nothing is spent).
func check(wizard: WizardBody, spell: SpellType, _point: Vector3, _picked: Node3D, funds: String) -> Aim:
	var aim := Aim.new()
	aim.point = wizard.global_position
	aim.target = wizard
	if not funds.is_empty():
		aim.status = funds
		return aim
	var ward := _ward(wizard, spell)
	if ward == null:
		aim.status = NOT_IMPLEMENTED
	elif ward.is_on():
		aim.status = BAD_TARGET
	return aim


## The hands throw the particle of the ward's own type, so every peer knows which spell is being cast (Ward.cast_type).
func begin(wizard: WizardBody, spell: SpellType, _aim: Aim) -> void:
	var ward := _ward(wizard, spell)
	cast_fx = ward.cast_fx_name() if ward != null else ""


func finish(wizard: WizardBody, spell: SpellType, _target: Node3D) -> String:
	var ward := _ward(wizard, spell)
	if ward != null:
		ward.start_for(spell)
	return ""


func _ward(wizard: WizardBody, spell: SpellType) -> Ward:
	var wards := Wards.of(wizard)
	return wards.ward_for(spell) if wards else null
