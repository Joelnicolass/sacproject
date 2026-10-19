class_name ThrownAction
extends AimedAction

## A guided ball that leaves the wizard's hands (Wrath, Fireball, Insect Swarm). `projectile_kind` names its
## scene in SpellSpawner; `launch_at_finish` says whether it leaves when the casting ends (Wrath,
## sacengine updateWrathCasting) or as soon as the cast starts (Fireball, Swarm). It explodes with
## `damage_range` splash around the body it hits.

## Kind of the projectile scene in SpellSpawner.
@export var projectile_kind := ""
@export var launch_at_finish := false

## Where the click was, in case the body is gone when the casting ends.
var _point := Vector3.ZERO


func begin(_wizard: WizardBody, _spell: SpellType, aim: Aim) -> void:
	_point = aim.point


func started(wizard: WizardBody, spell: SpellType, aim: Aim, _frames: int) -> void:
	if not launch_at_finish:
		_throw(wizard, spell, aim.target, aim.point)


func finish(wizard: WizardBody, spell: SpellType, target: Node3D) -> String:
	if launch_at_finish:
		_throw(wizard, spell, target, _point)
	return ""


func cancel() -> void:
	_point = Vector3.ZERO


func _throw(wizard: WizardBody, spell: SpellType, target: Node3D, point: Vector3) -> void:
	var spawner := projectile_spawner()
	if spawner == null:
		return
	var data := projectile_data(wizard, spell, hand_origin(wizard), target, point)
	data["damage_range"] = spell.damage_range
	spawner.spawn_projectile(projectile_kind, data)
