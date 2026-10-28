@tool
class_name RockAction
extends SpellAction

## Rock (kcor): the rock rises out of the ground while the wizard casts and flies when the casting ends.
## The projectile is spawned when the cast starts and knows how many casting frames
## it has to wait; what it does after that is the projectile's.
## Ref: sacengine castRock

## The rock scene (its root is a RockProjectile).
@export var projectile: PackedScene
## Who may be hit (a living body of another player).
@export var target: SpellTarget


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if target == null:
		warnings.append("Falta `target`: quién es un blanco válido.")
	if projectile == null:
		warnings.append("`projectile` is empty: drag the rock scene.")
	return warnings


func check(wizard: WizardBody, spell: SpellType, point: Vector3, picked: Node3D, funds: String) -> Aim:
	return aim_at_body(wizard, spell, point, funds, target.pick(wizard, picked) if target != null else null)


func started(wizard: WizardBody, spell: SpellType, aim: Aim, frames: int) -> void:
	if projectile == null:
		push_error("RockAction %s: `projectile` is empty, no rock is raised." % name)
		return
	var spawner := projectile_spawner()
	if spawner == null:
		return
	var launch := ProjectileLaunch.toward(wizard, spell, RockProjectile.cast_position(wizard), aim.target, aim.point)
	launch.cast_ticks = frames
	spawner.spawn_launch(projectile, launch)
