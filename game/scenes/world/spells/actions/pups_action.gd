class_name PupsAction
extends AimedAction

## Speedup (pups): an ally or the wizard himself runs faster for a while (sacengine speedUp). The effect is
## a SpeedupEffect child of the body, made as soon as the cast starts (it works at once). A body that
## already has one is not a valid target (the spell's exclusion).

@export var effect_scene: PackedScene


func resolve_target(wizard: WizardBody, spell: SpellType, picked: Node3D) -> Node3D:
	var body := ally_or_self(wizard, picked)
	if body == null or SpeedupEffect.duration_s(body, spell) < 0.0:
		return null
	return body


func started(_wizard: WizardBody, spell: SpellType, aim: Aim, _frames: int) -> void:
	var seconds := SpeedupEffect.duration_s(aim.target, spell)
	if seconds < 0.0:
		return
	var effect := effect_scene.instantiate() as SpeedupEffect
	effect.name = SpeedupEffect.NODE_NAME
	effect.start(seconds)
	aim.target.add_child(effect)
	FxBus.broadcast("speedup", aim.target.global_position + Vector3.UP)
