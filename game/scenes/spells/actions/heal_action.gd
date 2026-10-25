@tool
class_name HealAction
extends SpellAction

## Heal (laeh): an ally or the wizard is healed over time when the casting ends (sacengine heal). The
## body needs a Health; HealEffect adds up when the body is healed twice.

## Who may be healed (own creature or the wizard himself; not only living ones).
@export var target: SpellTarget


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if target == null:
		warnings.append("Falta `target`: quién es un blanco válido.")
	return warnings


func check(wizard: WizardBody, spell: SpellType, point: Vector3, picked: Node3D, funds: String) -> Aim:
	var body := target.pick(wizard, picked) if target != null else null
	return aim_at_body(wizard, spell, point, funds, body if body != null and body.get_node_or_null("Health") != null else null)


func finish(_wizard: WizardBody, spell: SpellType, body: Node3D) -> String:
	if body and HealEffect.can_heal(body):
		(HealEffect.on(body) as HealEffect).add(float(spell.damage))
		print("cura %d a %s" % [spell.damage, body.name])
	return ""
