@tool
class_name WardAction
extends SpellAction

## A spell that switches on one of the wards of a body (Skin of Stone, Air Shield, Ethereal Form, Fireform, Protective Swarm on the wizard
## himself: the key starts the cast, no click; Healing Aura on a creature the click names). When the casting time ends the Ward of that
## spell runs for the spell's duration. One scene for all of them; the numbers are the SpellType's and the Ward's. It does not scale damage
## (Wards) nor push, burn or heal anyone (BodyAura).
## Ref: sacengine skinOfStone, airShield, etherealForm, fireform, protectiveSwarm, healingAura (state.d:10591-10686, 11076-11088).

const _ROCK := preload("res://scenes/spells/rock_projectile.gd")

## Who carries the ward. Empty = the wizard himself.
@export var target: SpellTarget


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if target == null and pick != Pick.SELF:
		warnings.append("Sin `target`, el hechizo cae sobre el mago: `pick` tiene que ser SELF.")
	return warnings


## Funds first, then the carrier (valid, in range), then the ward: missing = NOT_IMPLEMENTED, already on = BAD_TARGET (nothing is spent).
func check(wizard: WizardBody, spell: SpellType, point: Vector3, picked: Node3D, funds: String) -> Aim:
	var aim := Aim.new()
	aim.point = wizard.global_position
	aim.target = wizard
	if not funds.is_empty():
		aim.status = funds
		return aim
	if target != null:
		aim.target = target.pick(wizard, picked)
		aim.point = aim.target.global_position if aim.target != null else point
		if aim.target == null:
			aim.status = BAD_TARGET
			return aim
		aim.status = standing_status(funds, wizard, spell, aim.point)
		if not aim.status.is_empty():
			return aim
	var ward := _ward(aim.target, spell)
	if ward == null:
		aim.status = NOT_IMPLEMENTED
	elif ward.is_on():
		aim.status = BAD_TARGET
	return aim


## The hands throw the particle of the ward's own type, so every peer knows which spell is being cast (Ward.cast_type).
func begin(wizard: WizardBody, spell: SpellType, aim: Aim) -> void:
	var ward := _ward(aim.target if aim.target != null else wizard, spell)
	cast_fx = ward.cast_type if ward != null else null


func finish(wizard: WizardBody, spell: SpellType, carrier: Node3D) -> String:
	var body := carrier if carrier != null else wizard
	var ward := _ward(body, spell)
	if ward != null and _ROCK.is_live_body(body):
		ward.start_for(spell)
	return ""


func _ward(body: Node3D, spell: SpellType) -> Ward:
	var wards := Wards.of(body)
	return wards.ward_for(spell) if wards else null
