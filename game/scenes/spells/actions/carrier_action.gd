@tool
class_name CarrierAction
extends SpellAction

## A spell that sends a carrier (Dragonfire's dragon, Charm's spirits, Blind Rage's fist, the vaporizing shot, Bovine Intervention's cow, Death).
## The click names the body (`target` says who is valid; a spell that also takes a click on the ground says so with `ground_ok`). The carrier is
## made through the SpellSpawner (so every peer draws it) when the cast starts or ends (`spawn_when`), where `spawn_at` says; when the casting time
## ends it is let go toward the body. If the wizard is cut it goes away. It does not fly nor hurt (SpellCarrier and its children) and it does not
## know which spell it is.
## Ref: sacengine castDragonfire, castBovineIntervention bovineIntervention, castDeath (state.d:10926-10939, 11257-11286, 11341-11354).

enum When { START, FINISH }
enum Where { WIZARD, AHEAD_OF_WIZARD, AIM }

## Who the click may name.
@export var target: SpellTarget
## The key of the carrier scene in SpellSpawner.projectiles.
@export var kind := ""
## A click on the ground is a valid aim (Death); the carrier then has no target body.
@export var ground_ok := false
@export_group("Birth")
@export var spawn_when := When.START
## WIZARD: on the wizard. AHEAD_OF_WIZARD: `ahead_m` in front of him, on the land. AIM: where the click landed (on a body, `ahead_m` in front of the wizard from its feet).
@export var spawn_at := Where.WIZARD
@export_range(0.0, 50.0, 0.5, "suffix:m") var ahead_m := 0.0
## It is born this far under the land (the cow).
@export_range(0.0, 20.0, 0.5, "suffix:m") var depth_m := 0.0
## Played on every peer at the aim while the wizard casts (the earth that rises under the cow). Its root answers play(params): `ticks`, `target`.
@export var cast_scene: PackedScene

var _carrier: SpellCarrier
var _released := false
var _aim: Aim
var _ticks := 0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if target == null:
		warnings.append("Falta `target`: quién es un blanco válido.")
	if kind.is_empty():
		warnings.append("Falta `kind`: la clave del portador en SpellSpawner.projectiles.")
	return warnings


## Funds first, then a valid body (or the ground), then the range: the order every spell of the book answers in.
func check(wizard: WizardBody, spell: SpellType, point: Vector3, picked: Node3D, funds: String) -> Aim:
	var aim := Aim.new()
	aim.point = point
	if not funds.is_empty():
		aim.status = funds
		return aim
	aim.target = target.pick(wizard, picked) if target != null else null
	if aim.target == null and not (ground_ok and picked == null):
		aim.status = BAD_TARGET
	else:
		var at := aim.target.global_position if aim.target != null else point
		if wizard.global_position.distance_to(at) > spell.cast_range_m:
			aim.status = OUT_OF_RANGE
	return aim


func started(wizard: WizardBody, spell: SpellType, aim: Aim, frames: int) -> void:
	_aim = aim
	_ticks = frames
	if cast_scene != null:
		FxBus.broadcast_scene(cast_scene.resource_path, _birth(wizard, aim), {"ticks": frames, "target": str(aim.target.get_path()) if aim.target != null else ""})
	if spawn_when == When.START:
		_spawn(wizard, spell)


func finish(wizard: WizardBody, spell: SpellType, picked: Node3D) -> String:
	if spawn_when == When.FINISH:
		_spawn(wizard, spell)
	if _carrier != null and is_instance_valid(_carrier):
		_released = true
		_carrier.arm(picked if picked != null else _aim.target)
	return ""


func cancel() -> void:
	if _carrier != null and is_instance_valid(_carrier) and not _released:
		_carrier.stop()
	_carrier = null


func _spawn(wizard: WizardBody, spell: SpellType) -> void:
	var spawner := SpellSpawner.of(get_tree())
	if spawner == null:
		push_warning("CarrierAction: no hay SpellSpawner (grupo spell_spawner).")
		return
	var at := _birth(wizard, _aim) - Vector3.UP * depth_m
	var data := AimedAction.projectile_data(wizard, spell, at, _aim.target, _aim.point)
	data["damage_range"] = spell.damage_range_m
	data["cast_ticks"] = _ticks
	_carrier = spawner.spawn_projectile(kind, data) as SpellCarrier
	_released = false
	if _carrier != null:
		_carrier.begin(wizard, spell, _aim.target, _aim.point, _ticks if spawn_when == When.START else 0)


## Where the carrier is born (on the land, before it is sunk): see `spawn_at`.
func _birth(wizard: WizardBody, aim: Aim) -> Vector3:
	var at := wizard.global_position
	if spawn_at == Where.AHEAD_OF_WIZARD:
		at += wizard.facing_flat() * ahead_m
	elif spawn_at == Where.AIM:
		at = aim.target.global_position if aim.target != null else aim.point
		if aim.target != null:
			at += wizard.facing_flat() * ahead_m
	var ground := GroundRay.surface_y(wizard, at, 1, GroundRay.wizard_rids(wizard.get_tree()), NAN)
	return at if is_nan(ground) or spawn_at == Where.WIZARD else Vector3(at.x, ground, at.z)
