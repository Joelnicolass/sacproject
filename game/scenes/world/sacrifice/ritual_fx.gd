@tool
class_name RitualFx
extends Node3D

## What is seen of a ritual, on every peer with meshes (the dedicated server draws nothing), derived only
## from replicated state: `ritual.phase`, the creature path, the wizards by slot. It moves nothing.
## - The red vortex over the drained wizard, 12.5 m from him toward the altar, 15 m up, for the whole
##   ritual (sacengine RedVortex.desecrateDistance / desecrateHeight, state.d:15878-15889, 15961-15973).
## - While the doctors shoot: `altar_bolts` ropes from high over the altar to the creature, and
##   `drain_bolts` ropes from the vortex to the wizard (sacengine altarBolts / desecrateBolts,
##   renderer.d:1948-1958). ESTIMADO: the original draws LightningBolts that change shape every 6-9
##   ticks; here they are the spring ropes of Tether (the same ltn2 atlas).
## - The doctors' own ropes to the creature are drawn by their CarryRope (`doctor.carried`).
## Remove this node from ritual.tscn to switch all of it off; the brightness is the `energy_scale`
## of the bolt scene.

## scenes/world/sacrifice/red_vortex.tscn
@export var vortex_scene: PackedScene
## scenes/fx/tether.tscn
@export var bolt_scene: PackedScene
@export var ritual: Ritual
@export_range(0, 6) var altar_bolts := 2
@export_range(0, 6) var drain_bolts := 3
## Height of the point the altar bolts start from (sacengine: 60 m over the altar).
@export var altar_bolt_height := 60.0
## Side offsets of each bolt's start so they do not overlap (estimado).
@export var bolt_spread := 1.5
## RedVortex.desecrateDistance and desecrateHeight.
@export var vortex_distance := 12.5
@export var vortex_height := 15.0
@export var follow_speed := 8.0

var _vortex: RedVortex
var _altar_top: Marker3D
var _vortex_aim: Marker3D
var _creature_aim: Marker3D
var _wizard_aim: Marker3D
var _altar_ropes: Array[Tether] = []
var _drain_ropes: Array[Tether] = []
var _built := false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if ritual == null:
		warnings.append("Asigná en `ritual` el Ritual que se dibuja.")
	if vortex_scene == null:
		warnings.append("Asigná en `vortex_scene` el vórtice rojo (red_vortex.tscn).")
	if bolt_scene == null:
		warnings.append("Asigná en `bolt_scene` la cuerda de los rayos (tether.tscn).")
	return warnings


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or ritual == null or not BodyCatalog.loads_meshes():
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
	if bolt_scene == null:
		return
	if not _built:
		_build()
	var creature := ritual.get_node_or_null(ritual.creature_path) as UnitBody if not ritual.creature_path.is_empty() else null
	if shooting and creature != null:
		_altar_top.global_position = ritual.center() + Vector3.UP * altar_bolt_height
		_creature_aim.global_position = creature.soul_anchor()
	if shooting and wizard != null and _vortex != null and is_instance_valid(_vortex):
		_vortex_aim.global_position = _vortex.global_position
		_wizard_aim.global_position = wizard.global_position + Vector3.UP * 1.5
	for rope in _altar_ropes:
		rope.end = _creature_aim if shooting and creature != null else null
	for rope in _drain_ropes:
		rope.end = _wizard_aim if shooting and wizard != null and _vortex != null else null


func _build() -> void:
	_built = true
	_altar_top = _marker("AltarTop")
	_vortex_aim = _marker("VortexAim")
	_creature_aim = _marker("CreatureAim")
	_wizard_aim = _marker("WizardAim")
	for i in altar_bolts:
		_altar_ropes.append(_rope(_altar_top, i, altar_bolts))
	for i in drain_bolts:
		_drain_ropes.append(_rope(_vortex_aim, i, drain_bolts))


## A rope starts at a marker child of its own so each bolt leaves from a slightly different point.
func _rope(origin: Marker3D, index: int, count: int) -> Tether:
	var start := Marker3D.new()
	start.name = "%sStart%d" % [origin.name, index]
	origin.add_child(start)
	start.position = Vector3((float(index) - 0.5 * float(count - 1)) * bolt_spread, 0.0, 0.0)
	var rope := bolt_scene.instantiate() as Tether
	rope.elbow = 0.0
	rope.start = start
	add_child(rope)
	return rope


func _marker(marker_name: String) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = marker_name
	add_child(marker)
	return marker


## The wizard being drained: only Desecrate has one (Convert drains nobody, no vortex over anyone).
func _wizard() -> WizardBody:
	if ritual.kind != Ritual.Kind.DESECRATE:
		return null
	for node in get_tree().get_nodes_in_group("wizard"):
		var wizard := node as WizardBody
		if wizard != null and wizard.owner_slot == ritual.target_slot:
			return wizard
	return null
