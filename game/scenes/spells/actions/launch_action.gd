@tool
class_name LaunchAction
extends SpellAction

## A spell that puts something into the world while the wizard casts and lets go of it when the casting ends: Chain Lightning and Rainbow
## (a ChainHop), Halo of Earth (the rocks). One script for all of them: `target` says who the click may name, `launch_scene` is what is
## made (its root is a SpellLaunch). When the cast starts the launch is made in the shot container; when the casting time ends it is
## released; if the wizard is cut it is aborted. `cast_scene` is the look the wizard's cast has on every peer. It does not hurt nor heal
## (the launch does) and it does not know which spell it is.

## Who the click may name. SELF casts on the key (set `pick` to SELF too).
@export var target: SpellTarget
## What is made when the cast starts (the root is a SpellLaunch).
@export var launch_scene: PackedScene
## Played on every peer while the wizard casts (FxBus.broadcast_scene). Its root answers play(params): `ticks` and the `wizard` path. Optional.
@export var cast_scene: PackedScene
## A second cast is refused while the first launch still runs (the halo: BAD_TARGET, nothing is spent).
@export var one_at_a_time := false

var _launch: SpellLaunch
var _released := false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if target == null:
		warnings.append("`target` is missing: who is a valid target.")
	if launch_scene == null:
		warnings.append("`launch_scene` is missing: what the spell puts in the world.")
	return warnings


## Funds first, then «already one» (when asked), a valid body and the range: the order every spell of the book answers in.
func check(
	wizard: WizardBody, spell: SpellType, point: Vector3, picked: Node3D, funds: String
) -> Aim:
	var aim := Aim.new()
	aim.point = point
	if not funds.is_empty():
		aim.status = funds
		return aim
	aim.target = target.pick(wizard, picked) if target != null else null
	if aim.target == null or (one_at_a_time and _running()):
		aim.status = BAD_TARGET
	elif wizard.global_position.distance_to(aim.target.global_position) > spell.cast_range_m:
		aim.status = OUT_OF_RANGE
	return aim


func started(wizard: WizardBody, spell: SpellType, aim: Aim, frames: int) -> void:
	var container := _container()
	if launch_scene == null or container == null:
		push_warning("LaunchAction: no scene or no shot container (group shot_spawner).")
		return
	_launch = launch_scene.instantiate() as SpellLaunch
	_released = false
	container.add_child(_launch)
	_launch.begin_cast(wizard, spell, aim.target, aim.point, frames)
	if cast_scene != null:
		FxBus.broadcast_scene(
			cast_scene, wizard.global_position, {"ticks": frames, "wizard": str(wizard.get_path())}
		)


func finish(_wizard: WizardBody, _spell: SpellType, picked: Node3D) -> String:
	if _launch != null and is_instance_valid(_launch):
		_released = true
		_launch.release(picked)
	return ""


func cancel() -> void:
	if _launch != null and is_instance_valid(_launch) and not _released:
		_launch.abort()
	_launch = null


func _running() -> bool:
	return _launch != null and is_instance_valid(_launch) and _launch.is_running()


## The node the shot spawner spawns into, or null (a world with none).
func _container() -> Node:
	var spawner := ShotSpawner.of(get_tree())
	return spawner.container() if spawner != null else null
