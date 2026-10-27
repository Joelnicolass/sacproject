@tool
class_name RockAction
extends SpellAction

## Rock (kcor): the rock rises out of the ground while the wizard casts and flies when the casting ends.
## The projectile is spawned when the cast starts and knows how many casting frames
## it has to wait; what it does after that is the projectile's.
## Ref: sacengine castRock

const _ROCK_PROJECTILE := preload("res://scenes/spells/rock_projectile.gd")

## Kind of the projectile scene in SpellSpawner.
@export var projectile_kind := "Rock"
## Who may be hit (a living body of another player).
@export var target: SpellTarget


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if target == null:
		warnings.append("Falta `target`: quién es un blanco válido.")
	return warnings


func check(wizard: WizardBody, spell: SpellType, point: Vector3, picked: Node3D, funds: String) -> Aim:
	return aim_at_body(wizard, spell, point, funds, target.pick(wizard, picked) if target != null else null)


func started(wizard: WizardBody, spell: SpellType, aim: Aim, frames: int) -> void:
	var spawner := projectile_spawner()
	if spawner == null:
		return
	var data := LaunchPoint.projectile_data(wizard, spell, _ROCK_PROJECTILE.cast_position(wizard), aim.target, aim.point)
	data["cast_frames"] = frames
	spawner.spawn_projectile(projectile_kind, data)
