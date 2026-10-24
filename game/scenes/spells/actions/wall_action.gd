@tool
class_name WallAction
extends SpellAction

## A spell that raises a wall on the ground (Firewall, Wall of Spikes, Wailing Wall, Vinewall, Fence): the click names a point of the land
## within range; the wall is born there when the cast starts, perpendicular to the line from the wizard to the point, grows while he casts and
## starts to act when the casting time ends; if he is interrupted it sinks at once. One scene per spell: the kind of wall and the cast
## particle change, not the script. It does not grow the wall nor hurt anybody (SpellWall and WallTouch do).
## Ref: sacengine castFirewall, castWailingWall, castVinewall, castWallOfSpikes, castFence (state.d:11118-11211).

## Key of the wall scene in SpellSpawner.
@export var wall_kind := ""

## The wall of the cast in progress (server only).
var _wall: SpellWall


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if wall_kind.is_empty():
		warnings.append("Escribí en `wall_kind` la clave del muro en SpellSpawner.")
	return warnings


## Funds first, then the range, then the land under the click (the order of the whole book).
func check(wizard: WizardBody, spell: SpellType, point: Vector3, _picked: Node3D, funds: String) -> Aim:
	var aim := Aim.new()
	aim.point = point
	if not funds.is_empty():
		aim.status = funds
		return aim
	aim.status = standing_status("", wizard, spell, point)
	if aim.status.is_empty() and not BodyNudge.on_land(wizard, point):
		aim.status = Refusal.NO_GROUND
	return aim


## The wall is born now: in the original it already grows during the casting time.
func started(wizard: WizardBody, _spell: SpellType, aim: Aim, _frames: int) -> void:
	var spawner := projectile_spawner()
	if spawner == null:
		return
	var run := WallRules.direction_for(wizard.global_position, aim.point, wizard.facing_flat())
	_wall = spawner.spawn_projectile(wall_kind, {
		"x": aim.point.x, "y": aim.point.y, "z": aim.point.z,
		"dir_x": run.x, "dir_z": run.y,
		"caster": str(wizard.get_path()),
		"slot": wizard.owner_slot,
	}) as SpellWall


func finish(_wizard: WizardBody, _spell: SpellType, _target: Node3D) -> String:
	if _wall != null and is_instance_valid(_wall):
		_wall.arm()
	_wall = null
	return ""


func cancel() -> void:
	if _wall != null and is_instance_valid(_wall):
		_wall.stop()
	_wall = null
