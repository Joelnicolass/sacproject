@tool
class_name PlayerStart
extends Node3D

## Where one player starts: the altar of that slot and, in `WizardSpot`, the spot where its wizard appears (move and turn the
## marker with the gizmo: the wizard stands where it stands, looking where it looks). The name over it (Preview) only lives in
## the editor. `team` says who this seat is allied with: seats with the same
## team above 0 are allies, 0 is alone (MapSides reads it with `slot`).

const SCENE_PATH := "res://scenes/map/props/player_start.tscn"
const LABEL_TEXT := "Player %d"

## Player slot of this start (1 = first player).
@export_range(1, 8) var slot := 1:
	set(value):
		slot = value
		_refresh_starts()
## Seats with the same team above 0 are allies; 0 = on its own (an enemy of every other seat).
@export_range(0, 8) var team := 0


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		_claim_altar()


func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_starts()
		_show_preview()
		return
	var preview := get_node_or_null("%Preview")
	if preview:
		preview.queue_free()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		for other in _other_starts():
			other.update_configuration_warnings.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_clear_preview()
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		_show_preview()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if get_node_or_null("%WizardSpot") == null:
		warnings.append("The WizardSpot child is missing: the wizard appears there.")
	if get_node_or_null("%Altar") == null:
		warnings.append("The Altar child is missing.")
	for other in _other_starts():
		if other.slot == slot:
			(
				warnings
				. append(
					(
						"Slot %d is already used by another start (%s). Every start needs a different number."
						% [slot, other.name]
					)
				)
			)
	return warnings


## Where the wizard of this slot appears, in global space: the origin and the turn of `WizardSpot`.
func spawn_transform() -> Transform3D:
	var spot := get_node_or_null("%WizardSpot") as Marker3D
	return spot.global_transform if spot != null else global_transform


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


## The preview is rebuilt on every load: nothing of it is written to player_start.tscn.
func _clear_preview() -> void:
	if not Engine.is_editor_hint():
		return
	var label := get_node_or_null("%PreviewLabel") as Label3D
	if label:
		label.text = ""


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
