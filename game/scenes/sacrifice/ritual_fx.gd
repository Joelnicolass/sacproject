@tool
class_name RitualFx
extends Node3D

## What is seen of a ritual, on every peer with meshes (the dedicated server draws nothing), derived only from replicated state:
## `ritual.phase`, the creature path, the wizards by slot. It moves nothing.
## - The red vortex over the drained wizard (a type that `drains_target_wizard`), 12.5 m from him toward the altar, 15 m up, for
##   the whole ritual.
## - While the doctors shoot: the `altar_ropes` go from the `AltarTop` marker (60 m over the altar) to the creature, and the
##   `drain_ropes` from the vortex to the wizard. ESTIMADO: the original draws LightningBolts that change shape every 6-9 ticks;
##   here they are the spring ropes of Tether (the same ltn2 atlas). Markers, start points and ropes are nodes of ritual.tscn:
##   drag them, add a rope by instancing tether.tscn and listing it.
## - The blood of a completed ritual (`blood_fx`), when RitualPayoff asks for it.
## - The doctors' own ropes to the creature are drawn by their CarryRope (`doctor.carried`).
## Remove this node from ritual.tscn to switch all of it off; the brightness is the `energy_scale` of the ropes.
## Ref: sacengine RedVortex.desecrateDistance / desecrateHeight (state.d:15878-15889, 15961-15973), altarBolts / desecrateBolts end at the `center` of the creature and the wizard (renderer.d:1948-1958).

## scenes/sacrifice/red_vortex.tscn
@export var vortex_scene: PackedScene
@export var ritual: Ritual
## data/fx/blood.tres: what the creature becomes when the ritual completes.
@export var blood_fx: ParticleType
@export_group("Markers")
## Over the altar (60 m up in the scene): where the altar ropes start from.
@export var altar_top: Marker3D
## Moved to the vortex while shooting: where the drain ropes start from.
@export var vortex_aim: Marker3D
## Moved to the creature's soul anchor while shooting: where the altar ropes end.
@export var creature_aim: Marker3D
## Moved to the drained wizard's center socket (BodyFacts) while shooting: where the drain ropes end.
@export var wizard_aim: Marker3D
@export_group("Ropes")
## Each one starts at its own marker child of `altar_top` / `vortex_aim`, so the bolts do not overlap.
@export var altar_ropes: Array[Tether]
@export var drain_ropes: Array[Tether]
@export_group("Vortex")
## RedVortex.desecrateDistance and desecrateHeight.
@export var vortex_distance := 12.5
@export var vortex_height := 15.0
@export var follow_speed := 8.0

var _vortex: RedVortex


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if ritual == null:
		warnings.append("Asigná en `ritual` el Ritual que se dibuja.")
	if vortex_scene == null:
		warnings.append("Asigná en `vortex_scene` el vórtice rojo (red_vortex.tscn).")
	if altar_top == null or vortex_aim == null or creature_aim == null or wizard_aim == null:
		warnings.append("Asigná los cuatro marcadores (altar_top, vortex_aim, creature_aim, wizard_aim).")
	return warnings


## The creature turns to blood (every peer sees it: the server broadcasts).
func splash_blood(at: Vector3) -> void:
	if blood_fx != null:
		FxBus.broadcast(blood_fx, at)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or ritual == null or not BodyLook.loads_meshes():
		return
	var live := ritual.outcome == Ritual.Outcome.RUNNING and ritual.phase != Ritual.Phase.OFF
	var wizard := _wizard()
	if live and wizard != null:
		_show_vortex(wizard, delta)
	else:
		_hide_vortex()
	var shooting := live and ritual.phase == Ritual.Phase.SHOOT
	_ropes(shooting, wizard)


func _show_vortex(wizard: WizardBody, delta: float) -> void:
	if vortex_scene == null:
		return
	if _vortex == null or not is_instance_valid(_vortex):
		_vortex = vortex_scene.instantiate() as RedVortex
		add_child(_vortex)
		_vortex.top_level = true
		_vortex.global_position = _vortex_point(wizard)
	var wanted := _vortex_point(wizard)
	_vortex.global_position = _vortex.global_position.lerp(wanted, 1.0 - exp(-follow_speed * delta))


func _hide_vortex() -> void:
	if _vortex != null and is_instance_valid(_vortex):
		_vortex.queue_free()
	_vortex = null


## 12.5 m from the wizard toward the altar, 15 m over his ground.
func _vortex_point(wizard: WizardBody) -> Vector3:
	var toward := ritual.center() - wizard.global_position
	toward.y = 0.0
	toward = toward.normalized() if toward.length_squared() > 0.000001 else Vector3.ZERO
	return wizard.global_position + toward * minf(vortex_distance, Vector2(ritual.center().x - wizard.global_position.x, ritual.center().z - wizard.global_position.z).length()) + Vector3.UP * vortex_height


func _ropes(shooting: bool, wizard: WizardBody) -> void:
	var creature := ritual.get_node_or_null(ritual.creature_path) as UnitBody if not ritual.creature_path.is_empty() else null
	if shooting and creature != null:
		creature_aim.global_position = creature.soul_anchor()
	if shooting and wizard != null and _vortex != null and is_instance_valid(_vortex):
		vortex_aim.global_position = _vortex.global_position
		wizard_aim.global_position = BodyFacts.point(wizard, BodyFacts.Socket.CENTER)
	for rope in altar_ropes:
		rope.end = creature_aim if shooting and creature != null else null
	for rope in drain_ropes:
		rope.end = wizard_aim if shooting and wizard != null and _vortex != null else null


## The wizard being drained: only a type that drains has one (Convert drains nobody, no vortex over anyone).
func _wizard() -> WizardBody:
	if not ritual.type().drains_target_wizard:
		return null
	for node in get_tree().get_nodes_in_group("wizard"):
		var wizard := node as WizardBody
		if wizard != null and wizard.owner_slot == ritual.target_slot:
			return wizard
	return null
