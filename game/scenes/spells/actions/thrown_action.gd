@tool
class_name ThrownAction
extends SpellAction

## A guided ball that leaves the wizard's hands (Wrath, Fireball, Insect Swarm). `projectile_kind` names its
## scene in SpellSpawner; `launch_at_finish` says whether it leaves when the casting ends (Wrath,
## sacengine updateWrathCasting) or as soon as the cast starts (Fireball, Swarm). It explodes with
## `damage_range` splash around the body it hits.

## Kind of the projectile scene in SpellSpawner.
@export var projectile_kind := ""
@export var launch_at_finish := false
## Who may be hit (a living body of another player).
@export var target: SpellTarget

## Where the click was, in case the body is gone when the casting ends.
var _point := Vector3.ZERO


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if target == null:
		warnings.append("Falta `target`: quién es un blanco válido.")
	return warnings


func check(wizard: WizardBody, spell: SpellType, point: Vector3, picked: Node3D, funds: String) -> Aim:
	return aim_at_body(wizard, spell, point, funds, target.pick(wizard, picked) if target != null else null)


func begin(_wizard: WizardBody, _spell: SpellType, aim: Aim) -> void:
	_point = aim.point


func started(wizard: WizardBody, spell: SpellType, aim: Aim, _frames: int) -> void:
	if not launch_at_finish:
		_throw(wizard, spell, aim.target, aim.point)


func finish(wizard: WizardBody, spell: SpellType, body: Node3D) -> String:
	if launch_at_finish:
		_throw(wizard, spell, body, _point)
	return ""


func cancel() -> void:
	_point = Vector3.ZERO


func _throw(wizard: WizardBody, spell: SpellType, body: Node3D, point: Vector3) -> void:
	var spawner := projectile_spawner()
	if spawner == null:
		return
	var data := LaunchPoint.projectile_data(wizard, spell, LaunchPoint.from_hand(wizard), body, point)
	data["damage_range"] = spell.damage_range_m
	spawner.spawn_projectile(projectile_kind, data)
