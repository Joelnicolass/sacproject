class_name ArtTab
extends VBoxContainer

## «Arte»: the look's own values, one by one (ArtPrefs), as if editing the Environment .tres and
## the lens flare's material. Pick a part in `Part`; its rows are the Environment properties with
## that prefix (or the flare's shader uniforms), each showing the value on screen now: in a match
## the world's, in the menu `fallback_environment`'s. A value the player set shows in the accent
## color; «↺» gives it back to the look. Named sets: «Guardar» / «Cargar» (user://art/<name>.json);
## «Exportar .tres» writes the whole live Environment with these values for the project.

## Part label key → Environment property prefix ("" = the lens flare's uniforms).
const PARTS := {
	"UI_ART_PART_FOG": "fog_",
	"UI_ART_PART_VOLUMETRIC": "volumetric_fog_",
	"UI_ART_PART_SSAO": "ssao_",
	"UI_ART_PART_SSIL": "ssil_",
	"UI_ART_PART_GLOW": "glow_",
	"UI_ART_PART_TONEMAP": "tonemap_",
	"UI_ART_PART_ADJUST": "adjustment_",
	"UI_ART_PART_AMBIENT": "ambient_light_",
	"UI_ART_PART_FLARE": "",
}

## What the rows show when no world is open (the boot menu).
@export var fallback_environment: Environment = preload("res://scenes/look/env_base.tres")
## The flare's shader, for its uniforms when no world is open.
@export var flare_shader: Shader = preload("res://scenes/look/flare/lens_flare.gdshader")
@export var tab_title := "UI_ART_TAB"

var _art: ArtPrefs
var _rows: Dictionary[StringName, PropertyRow] = {}
var _prefix := "fog_"


func _ready() -> void:
	_art = ArtPrefs.shared()
	var parts: OptionButton = %Part
	for key: String in PARTS:
		parts.add_item(tr(key))
		parts.set_item_metadata(parts.item_count - 1, PARTS[key])
	parts.item_selected.connect(_on_part)
	%Save.pressed.connect(_on_save)
	%Load.pressed.connect(_on_load)
	%Export.pressed.connect(_on_export)
	%ResetAll.pressed.connect(_art.clear_all)
	_art.changed.connect(_sync)
	visibility_changed.connect(_on_shown)
	_fill_saved()
	_build()


func _on_shown() -> void:
	if is_visible_in_tree():
		_fill_saved()
		_build()


func _on_part(index: int) -> void:
	_prefix = str(%Part.get_item_metadata(index))
	_build()


func _part() -> StringName:
	return &"flare" if _prefix.is_empty() else &"environment"


func _build() -> void:
	for row in _rows.values():
		row.queue_free()
	_rows.clear()
	var list: VBoxContainer = %List
	for info in _infos():
		if not PropertyRow.is_supported(info):
			continue
		var name := str(info["name"])
		var title := PropertyRow.humanize(name.trim_prefix(_prefix) if _prefix else name)
		var row := PropertyRow.make(info, title, null)
		row.edited.connect(func(p: StringName, v: Variant) -> void: _art.set_value(_part(), p, v))
		row.reset_requested.connect(func(p: StringName) -> void: _art.clear_value(_part(), p))
		list.add_child(row)
		_rows[row.property] = row
	_sync()


func _infos() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _prefix.is_empty():
		for uniform in flare_shader.get_shader_uniform_list():
			out.append(uniform)
		return out
	for info in Environment.new().get_property_list():
		if str(info["name"]).begins_with(_prefix) and int(info["usage"]) & PROPERTY_USAGE_EDITOR:
			out.append(info)
	return out


func _sync() -> void:
	var env := _live_environment()
	var flare := _live_flare()
	for property: StringName in _rows:
		var chosen: Variant = _art.value_of(_part(), property)
		var shown: Variant = chosen
		if shown == null:
			shown = (
				flare.get_shader_parameter(property)
				if _prefix.is_empty() and flare
				else (
					RenderingServer.shader_get_parameter_default(flare_shader.get_rid(), property)
					if _prefix.is_empty()
					else env.get(property)
				)
			)
		_rows[property].show_value(shown)
		_rows[property].set_changed(chosen != null)
	%ResetAll.disabled = _art.is_empty()


func _live_environment() -> Environment:
	var world := get_viewport().find_world_3d() if get_viewport() else null
	if world and world.environment:
		return world.environment
	return fallback_environment


func _live_flare() -> ShaderMaterial:
	var layer := get_tree().get_first_node_in_group(LensFlareLayer.GROUP) as LensFlareLayer
	return layer.flare_material() if layer else null


func _fill_saved() -> void:
	var saved: OptionButton = %Saved
	saved.clear()
	for name in _art.names():
		saved.add_item(name)
	%Load.disabled = saved.item_count == 0


func _on_save() -> void:
	var name: String = %SaveName.text
	if _art.save_as(name) == OK:
		%Status.text = tr("UI_ART_SAVED") % name
		_fill_saved()
	else:
		%Status.text = tr("UI_ART_BAD_NAME")


func _on_load() -> void:
	var saved: OptionButton = %Saved
	if saved.selected < 0:
		return
	var name := saved.get_item_text(saved.selected)
	var loaded := _art.load_named(name) == OK
	%Status.text = tr("UI_ART_LOADED" if loaded else "UI_ART_LOAD_FAILED") % name


func _on_export() -> void:
	var name: String = %SaveName.text if not %SaveName.text.is_empty() else "custom"
	var path := _art.export_environment(_live_environment(), name)
	%Status.text = (
		tr("UI_ART_EXPORTED") % ProjectSettings.globalize_path(path)
		if not path.is_empty()
		else tr("UI_ART_BAD_NAME")
	)
