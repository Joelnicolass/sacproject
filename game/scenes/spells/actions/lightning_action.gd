@tool
class_name LightningAction
extends SpellAction

## Lightning (ntil): an instant strike on a living enemy when the casting ends.
## The bolt is a BeamType drawn by FxBus; the damage is DamageMod.lightning, which charges a Storm Giant.

const _HEALTH := preload("res://scenes/components/health.gd")

## The bolt of the strike. Empty = it strikes unseen.
@export var beam: BeamType
## Who may be struck (a living body of another player).
@export var target: SpellTarget


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if target == null:
		warnings.append("`target` is missing: who is a valid target.")
	return warnings


func check(
	wizard: WizardBody, spell: SpellType, point: Vector3, picked: Node3D, funds: String
) -> Aim:
	return aim_at_body(
		wizard, spell, point, funds, target.pick(wizard, picked) if target != null else null
	)


func finish(wizard: WizardBody, spell: SpellType, body: Node3D) -> String:
	if body == null or not ProjectileTargets.is_live_body(body):
		return ""
	# DamageMod.lightning, which charges a Storm Giant.
	var taken := (body.get_node("Health") as Health).damage_typed(
		float(spell.damage),
		_HEALTH.DIRECT_SPELL,
		wizard.owner_slot,
		false,
		false,
		_HEALTH.LIGHTNING
	)
	ProjectileTargets.report(body, taken, _HEALTH.DIRECT_SPELL)
	if beam != null:
		FxBus.broadcast_beam(beam, _origin(wizard), ProjectileTargets.body_center(body), body)
	return ""


## The bolt starts 0.5 above the top of the
## wizard's hitbox and 0.75 ahead of its front. Presentation only.
func _origin(wizard: WizardBody) -> Vector3:
	var facts := BodyFacts.of_body(wizard)
	var at := wizard.global_position + Vector3(0.0, facts.height_m + 0.5, 0.0)
	at += wizard.facing_flat() * (facts.reach_m + 0.75)
	return at
