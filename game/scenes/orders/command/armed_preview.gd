class_name ArmedPreview
extends Node

## While a structure spell that aims at the ground is armed, a few times a second it asks the local
## Caster what a click at the pointer would answer (Caster.aim_for, the same rule the server runs,
## read only) and writes that answer to %Battle (`show_aim`). It also lights the ring of the fount
## it would build on: green when it would start, red when not. Local to the player's process: no
## RPC, it casts nothing and draws no cursor (CursorSkin, CommandCue and RefusalReason read
## %Battle). Common spells get no preview. Without this node only the flash after a refused click is
## left.

@export var armed: ArmedCommand
@export var ray: PointerRay
## Says when the pointer is over the HUD (then there is no preview) and where the pointer is.
@export var probe: TargetProbe
## Questions per second.
@export_range(1.0, 60.0, 1.0) var hz := 15.0

var _since := 0.0
var _ring_site: ManafountBody

@onready var _log: CommandLog = %Battle


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if armed == null:
		warnings.append("Assign `armed` (MatchCommand/ArmedCommand).")
	if ray == null:
		warnings.append("Assign `ray` (MatchCommand/PointerRay).")
	if probe == null:
		warnings.append("Assign `probe` (Hud/TargetProbe).")
	return warnings


func _ready() -> void:
	_log.armed_changed.connect(_on_armed_changed)
	set_process(false)


func _on_armed_changed(kind: String, _icon: Texture2D) -> void:
	set_process(kind == "structure")
	_since = 1.0
	if kind != "structure":
		_show(&"", null)


func _process(delta: float) -> void:
	_since += delta
	if _since < 1.0 / hz:
		return
	_since = 0.0
	preview()


## Asks now and shows the answer (a flow may call it to skip the wait).
func preview() -> void:
	var aim := _aim_at_pointer()
	if aim == null:
		_show(&"", null)
	else:
		_show(StringName(aim.status), aim.site)


## The answer of the armed structure at the pointer, or null when there is nothing to preview
## (another icon, an action that aims at a body, the pointer over the HUD or the sky, no wizard).
func _aim_at_pointer() -> SpellAction.Aim:
	if armed == null or armed.mode != "structure" or probe == null or probe.kind == TargetProbe.HUD:
		return null
	var caster := armed.caster
	if caster == null or not is_instance_valid(caster):
		return null
	var action := caster.structure_action(armed.structure_index)
	if action == null or action.pick != SpellAction.Pick.GROUND:
		return null
	var ground: Variant = ray.ground(probe.pointer_now())
	if ground == null:
		return null
	return caster.aim_for(action.tag, ground, null)


func _show(status: StringName, site: Node3D) -> void:
	_log.show_aim(status, site)
	var fount := site as ManafountBody
	if fount != _ring_site:
		_ring(_ring_site, BuildRing.State.HIDDEN)
		_ring_site = fount
	_ring(fount, BuildRing.State.OK if status.is_empty() else BuildRing.State.BLOCKED)


func _ring(fount: ManafountBody, state: BuildRing.State) -> void:
	if fount != null and is_instance_valid(fount) and fount.build_area != null:
		fount.build_area.show_preview(state)
