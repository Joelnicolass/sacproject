@tool
class_name PlayerStart
extends Node3D

## Where one player starts: the altar of that slot and the spot where its wizard appears.
## The wizard stands `wizard_distance` from the altar toward `faces`, looking at it
## (sacengine places it toward the closest manafount, state.d:2357-2388).
## The Preview child (ghost wizard and name) only lives in the editor.

const LABEL_TEXT := "Jugador %d"

## Player slot of this start (1 = first player).
@export_range(1, 8) var slot := 1:
	set(value):
		slot = value
		_refresh_starts()
## The manafount (or any Node3D) the wizard walks toward and looks at.
@export var faces: Node3D:
	set(value):
		faces = value
		update_configuration_warnings()
## Meters from the altar center to the wizard (the pillars stand at ±20).
@export var wizard_distance := 30.0
## Model of the ghost wizard shown in the editor.
@export var preview_model := "jnwr"

var _preview_state: Array = []


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		_claim_altar()


func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_starts()
		return
	set_process(false)
	var preview := get_node_or_null("%Preview")
	if preview:
		preview.queue_free()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		for other in _other_starts():
			other.update_configuration_warnings.call_deferred()


func _process(_delta: float) -> void:
	var state := [global_transform, faces.global_position if faces else Vector3.ZERO, slot, wizard_distance, preview_model]
	if state != _preview_state:
		_preview_state = state
		_show_preview()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_clear_preview()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_show_preview()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if faces == null:
		warnings.append("Asigná en `faces` el manantial hacia el que mira este inicio.")
	if get_node_or_null("%Altar") == null:
		warnings.append("Falta el hijo Altar.")
	for other in _other_starts():
		if other.slot == slot:
			warnings.append("El slot %d ya lo usa otro inicio (%s). Cada inicio necesita un número distinto." % [slot, other.name])
	return warnings


## Where the wizard of this slot appears, in global space: origin on the spot, turned to `faces`.
## `distance` below 0 uses wizard_distance. Past `faces` the wizard stands beyond it, still facing it.
func spawn_spot(distance := -1.0) -> Transform3D:
	var at := global_position
	var ahead := Vector3(0.0, 0.0, 1.0)
	if faces:
		var flat := faces.global_position - at
		flat.y = 0.0
		if flat.length_squared() > 0.000001:
			ahead = flat.normalized()
	var spot := at + ahead * (distance if distance >= 0.0 else wizard_distance)
	var facing := ahead
	if faces:
		var to_faces := faces.global_position - spot
		to_faces.y = 0.0
		if to_faces.length_squared() > 0.000001:
			facing = to_faces.normalized()
	return Transform3D(Basis(Vector3.UP, atan2(facing.x, facing.z)), spot)


## The altar (and through it its mana) belongs to this slot.
func _claim_altar() -> void:
	var altar := get_node_or_null("%Altar") as Altar
	if altar:
		altar.owner_slot = slot


func _show_preview() -> void:
	if not Engine.is_editor_hint() or not is_node_ready():
		return
	var label := get_node_or_null("%PreviewLabel") as Label3D
	if label:
		label.text = LABEL_TEXT % slot
	var wizard := get_node_or_null("%PreviewWizard") as Node3D
	if wizard:
		wizard.global_transform = spawn_spot()
	var visual := get_node_or_null("%PreviewVisual")
	if visual and visual.get("model") != preview_model:
		visual.set("model", preview_model)


## The preview is rebuilt on every load: nothing of it is written to player_start.tscn.
func _clear_preview() -> void:
	if not Engine.is_editor_hint():
		return
	var label := get_node_or_null("%PreviewLabel") as Label3D
	if label:
		label.text = ""
	var wizard := get_node_or_null("%PreviewWizard") as Node3D
	if wizard:
		wizard.transform = Transform3D.IDENTITY
	var visual := get_node_or_null("%PreviewVisual")
	if visual:
		visual.set("model", "")
	_preview_state = []


## The other starts of the same map: the siblings of this node.
func _other_starts() -> Array[PlayerStart]:
	var found: Array[PlayerStart] = []
	var parent := get_parent()
	if parent == null:
		return found
	for node in parent.get_children():
		var other := node as PlayerStart
		if other and other != self:
			found.append(other)
	return found


## A slot shared by two starts warns on both, so both refresh when one changes.
func _refresh_starts() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	update_configuration_warnings()
	for other in _other_starts():
		other.update_configuration_warnings()
