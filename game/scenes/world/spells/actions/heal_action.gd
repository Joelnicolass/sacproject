class_name HealAction
extends AimedAction

## Heal (laeh): an ally or the wizard is healed over time when the casting ends (sacengine heal). The
## body needs a Health; HealEffect adds up when the body is healed twice.


func resolve_target(wizard: WizardBody, _spell: SpellType, picked: Node3D) -> Node3D:
	var body := ally_or_self(wizard, picked)
	if body == null or body.get_node_or_null("Health") == null:
		return null
	return body


func finish(_wizard: WizardBody, spell: SpellType, target: Node3D) -> String:
	if target and HealEffect.can_heal(target):
		(HealEffect.on(target) as HealEffect).add(float(spell.damage))
		print("cura %d a %s" % [spell.damage, target.name])
	return ""
