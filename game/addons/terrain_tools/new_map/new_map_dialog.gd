@tool
extends ConfirmationDialog

## The «New map» dialog: a tag and a name, and below them, live, why the map cannot be made yet (Create stays off
## until it can). Frees itself once closed. Not: making the map (NewMapAction listens to `chosen`).

signal chosen(tag: StringName, display_name: String)

const NewMapFiles := preload("res://addons/terrain_tools/new_map/new_map_files.gd")

@onready var _tag: LineEdit = %Tag
@onready var _display_name: LineEdit = %DisplayName
@onready var _reason: Label = %Reason


func _ready() -> void:
	_tag.text_changed.connect(_on_changed.unbind(1))
	_display_name.text_changed.connect(_on_changed.unbind(1))
	confirmed.connect(_on_confirmed)
	visibility_changed.connect(func() -> void:
		if not visible:
			queue_free())
	register_text_enter(_display_name)
	_on_changed()
	_tag.grab_focus.call_deferred()


func _on_changed() -> void:
	var reason := NewMapFiles.refusal(_tag.text, _display_name.text)
	_reason.text = reason
	get_ok_button().disabled = not reason.is_empty()


func _on_confirmed() -> void:
	if NewMapFiles.refusal(_tag.text, _display_name.text).is_empty():
		chosen.emit(StringName(_tag.text), _display_name.text.strip_edges())
