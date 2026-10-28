@tool
class_name SpeedupAction
extends SpellAction

## Speedup: an ally or the wizard himself runs faster for a while. The effect is
## a SpeedupEffect child of the body, made as soon as the cast starts (it works at once). A body that
## already has one is not a valid target (the spell's exclusion).

@export var effect_scene: PackedScene
## Who may be sped up (own creature or the wizard himself; not only living ones).
@export var target: SpellTarget
## The burst on the body when it starts running faster, and where on the body.
@export var start_fx: ParticleType
@export var start_socket := BodyFacts.Socket.CENTER


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if target == null:
		warnings.append("`target` is missing: who is a valid target.")
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
	if start_fx != null:
		FxBus.broadcast(start_fx, BodyFacts.point(aim.target, start_socket))
