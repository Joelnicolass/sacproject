class_name AdvancedGraphicsTab
extends VBoxContainer

## «Avanzado»: every field of the graphics preset on its own (GraphicsPrefs.set_override), over the
## preset chosen in «Gráficos». The rows come from LookQuality's own exported fields, grouped as its
## inspector groups them, so a new field shows here with no code. A field the player set shows in
## the accent color; «↺» gives it back to the preset, «Todo como el preset» clears them all. A
## title is the translation of UI_QUALITY_<FIELD> (UI_QUALITY_GROUP_<GROUP> for a group) when there
## is one.

const SKIPPED: PackedStringArray = ["id", "label", "vegetation"]

@export var prefs: GraphicsPrefs
## The title of this tab in the options' TabContainer.
@export var tab_title := "UI_OPTIONS_TAB_ADVANCED"

var _rows: Dictionary[StringName, PropertyRow] = {}


func _ready() -> void:
	if prefs == null:
		return
	_build()
	_sync()
	%ResetAll.pressed.connect(prefs.clear_overrides)
	prefs.changed.connect(_sync)


func _build() -> void:
	var list: VBoxContainer = %List
	var sample := prefs.base_quality() if prefs.base_quality() else LookQuality.new()
	# A group's title shows only once a row of it does (Resource's own groups have none).
	var pending_group := ""
	for info in sample.get_property_list():
		var usage := int(info["usage"])
		if usage & PROPERTY_USAGE_GROUP:
			pending_group = str(info["name"])
			continue
		if (
			not usage & PROPERTY_USAGE_SCRIPT_VARIABLE
			or not usage & PROPERTY_USAGE_EDITOR
			or SKIPPED.has(str(info["name"]))
			or not PropertyRow.is_supported(info)
		):
			continue
		if not pending_group.is_empty():
			var header := Label.new()
			header.text = _title("UI_QUALITY_GROUP_", pending_group)
			header.theme_type_variation = &"LabelHeading"
			list.add_child(header)
			pending_group = ""
		var row := PropertyRow.make(info, _title("UI_QUALITY_", str(info["name"])), null)
		row.edited.connect(prefs.set_override)
		row.reset_requested.connect(prefs.clear_override)
		list.add_child(row)
		_rows[row.property] = row


func _sync() -> void:
	var shown := prefs.quality()
	if shown == null:
		return
	for property: StringName in _rows:
		_rows[property].show_value(shown.get(property))
		_rows[property].set_changed(prefs.override_of(property) != null)
	%ResetAll.disabled = not prefs.has_overrides()


func _title(prefix: String, name: String) -> String:
	var key := prefix + name.to_upper().replace(" ", "_")
	var text := tr(key)
	return text if text != key else PropertyRow.humanize(name)
