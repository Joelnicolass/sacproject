class_name RockAction
extends AimedAction

## Rock (kcor): the rock rises out of the ground while the wizard casts and flies when the casting ends
## (sacengine castRock). The projectile is spawned when the cast starts and knows how many casting frames
## it has to wait; what it does after that is the projectile's.

const _ROCK_PROJECTILE := preload("res://scenes/spells/rock_projectile.gd")

## Kind of the projectile scene in SpellSpawner.
@export var projectile_kind := "Rock"


func started(wizard: WizardBody, spell: SpellType, aim: Aim, frames: int) -> void:
	var spawner := projectile_spawner()
	if spawner == null:
		return
	var data := projectile_data(wizard, spell, _ROCK_PROJECTILE.cast_position(wizard), aim.target, aim.point)
	data["cast_frames"] = frames
	spawner.spawn_projectile(projectile_kind, data)
