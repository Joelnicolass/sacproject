@tool
class_name PupsAction
extends SpellAction

## Speedup (pups): an ally or the wizard himself runs faster for a while (sacengine speedUp). The effect is
## a SpeedupEffect child of the body, made as soon as the cast starts (it works at once). A body that
## already has one is not a valid target (the spell's exclusion).

@export var effect_scene: PackedScene
## Who may be sped up (own creature or the wizard himself; not only living ones).
@export var target: SpellTarget


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if target == null:
		warnings.append("Falta `target`: quién es un blanco válido.")
	return warnings


func check(wizard: WizardBody, spell: SpellType, point: Vector3, picked: Node3D, funds: String) -> Aim:
	var body := target.pick(wizard, picked) if target != null else null
	return aim_at_body(wizard, spell, point, funds, body if body != null and SpeedupEffect.duration_s(body, spell) >= 0.0 else null)


func started(_wizard: WizardBody, spell: SpellType, aim: Aim, _frames: int) -> void:
	var seconds := SpeedupEffect.duration_s(aim.target, spell)
	if seconds < 0.0:
		return
	var effect := effect_scene.instantiate() as SpeedupEffect
	effect.name = SpeedupEffect.NODE_NAME
	effect.start(seconds)
	aim.target.add_child(effect)
	FxBus.broadcast("speedup", aim.target.global_position + Vector3.UP)
