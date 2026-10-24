@tool
class_name CarrierAction
extends SpellAction

## A spell that sends a carrier flying (the dragon of Dragonfire). The click names the body (`target` says who is valid); when the cast
## starts the carrier is made through the SpellSpawner (so every peer draws it), it climbs around the wizard while he casts, and when the
## casting time ends it is let go toward the body. If the wizard is cut it goes away. It does not fly nor hurt (SpellCarrier and its
## CarrierArrive) and it does not know which spell it is.
## Ref: sacengine castDragonfire (state.d:10926-10939).

## Who the click may name.
@export var target: SpellTarget
## The key of the carrier scene in SpellSpawner.projectiles.
@export var kind := ""

var _carrier: SpellCarrier
var _released := false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if target == null:
		warnings.append("Falta `target`: quién es un blanco válido.")
	if kind.is_empty():
		warnings.append("Falta `kind`: la clave del portador en SpellSpawner.projectiles.")
	return warnings


## Funds first, then a valid body, then the range: the order every spell of the book answers in.
func check(wizard: WizardBody, spell: SpellType, point: Vector3, picked: Node3D, funds: String) -> Aim:
	var aim := Aim.new()
	aim.point = point
	if not funds.is_empty():
		aim.status = funds
		return aim
	aim.target = target.pick(wizard, picked) if target != null else null
	if aim.target == null:
		aim.status = BAD_TARGET
	elif wizard.global_position.distance_to(aim.target.global_position) > spell.cast_range:
		aim.status = OUT_OF_RANGE
	return aim


func started(wizard: WizardBody, spell: SpellType, aim: Aim, frames: int) -> void:
	var spawner := SpellSpawner.of(get_tree())
	if spawner == null:
		push_warning("CarrierAction: no hay SpellSpawner (grupo spell_spawner).")
		return
	var data := AimedAction.projectile_data(wizard, spell, wizard.global_position, aim.target, aim.point)
	data["damage_range"] = spell.damage_range
	data["cast_ticks"] = frames
	_carrier = spawner.spawn_projectile(kind, data) as SpellCarrier
	_released = false
	if _carrier != null:
		_carrier.begin(wizard, spell, aim.target, aim.point, frames)


func finish(_wizard: WizardBody, _spell: SpellType, picked: Node3D) -> String:
	if _carrier != null and is_instance_valid(_carrier):
		_released = true
		_carrier.arm(picked)
	return ""


func cancel() -> void:
	if _carrier != null and is_instance_valid(_carrier) and not _released:
		_carrier.stop()
	_carrier = null
