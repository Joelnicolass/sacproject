@tool
class_name SelectionRoster
extends Control

## The selected creatures at the left edge. Laid out in canvas pixels of the 1280×720 base (Godot's stretch scales them): the
## `Frame` panel (166×307 at x = -41, drawn by the theme variation HudRosterFrame) centered vertically, 41×38 cells (column 0 at
## x = -1, column 1 at x = 43, rows every 38 from y = 38) and the active ability's 41×41 icon at x = 85. The frame shows even when empty.
##
## Up to `capacity` (columns × rows) creatures: one cell each, the newest first, with its bars.
## More than that: one cell per type (largest group first) with the number of members, and the
## bars show Σhealth / Σmax of the group. A click on a cell narrows the selection (see
## _on_cell_activated); the roster never owns the selection, `Selection` does.
## Hidden on the dedicated server (no local player). The view refreshes the bars on a timer: no
## per-creature signal is connected.

## The ability icon was pressed; MatchCommand uses the selection's ability.
signal ability_pressed

## selection.gd has no class_name (other scripts preload it).
const _SELECTION := preload("res://scenes/orders/selection.gd")

## Local selection (`%Selection`).
@export var selection: Node
@export var cell_scene: PackedScene
@export var columns := 2
@export var rows := 6
@export var cell_size := Vector2(41.0, 38.0)
## Bars and tooltips refresh this often.
@export_range(1.0, 60.0, 1.0) var refresh_hz := 10.0
@export var tooltips := true

## Creatures selected, as the view last saw them.
var count := 0
## "unit" (one cell per creature) or "group" (one cell per type).
var mode := "unit"
## Microseconds the last rebuild took, and the last bar refresh (debug and flows).
var last_build_us := 0
var last_refresh_us := 0
## The ability whose icon is on show, null when there is none.
var ability: AbilityType
## Its tag, "" when there is none (flows read it).
var ability_tag := ""
## Text of a single creature «Trogg 960/960» or «N unidades»; never drawn, flows read it.
var summary: String:
	get:
		return _summary()
## Slot of the player of this process; 0 until `bind` (the dedicated server never binds: the roster stays hidden).
var local_slot := 0
## Cells on show (visible), readable by flows.
var cells_shown := 0
## Lowest health fraction among the cells on show after the last refresh (-1 with none); flows read it.
var min_health := -1.0

var _units: Array = []
var _cells: Array[RosterCell] = []


func capacity() -> int:
	return columns * rows


## Cell i fills by columns like renderSelectionRoster: column i / rows, row i % rows, for the first
## `capacity`; the types beyond it continue in rows under the sixth (they scroll).
func _slot_at(i: int) -> Vector2:
	var column := i / rows
	var row := i % rows
	if i >= capacity():
		column = (i - capacity()) % columns
		row = rows + (i - capacity()) / columns
	return Vector2(column * (cell_size.x + 2.0), row * cell_size.y)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if selection == null:
		warnings.append("selection is empty: assign the Selection node.")
	if cell_scene == null:
		warnings.append("cell_scene is empty: assign roster_cell.tscn.")
	return warnings


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	%Refresh.wait_time = 1.0 / refresh_hz
	%Refresh.timeout.connect(_on_refresh)
	%Ability.pressed.connect(ability_pressed.emit)
	%Ability.visible = false
	if selection:
		selection.changed.connect(_on_selection_changed)
		_on_selection_changed((selection as _SELECTION).units())
	_update_visible()


func _on_selection_changed(units: Array) -> void:
	var started := Time.get_ticks_usec()
	_units = units
	count = units.size()
	mode = "unit" if count <= capacity() else "group"
	if mode == "unit":
		_show_units()
	else:
		_show_groups()
	_show_ability()
	last_build_us = Time.get_ticks_usec() - started


func _show_units() -> void:
	_ensure_cells(count)
	for i in _cells.size():
		var cell := _cells[i]
		if i < count:
			var unit: Node = _units[i]
			cell.show_unit(unit, CreatureType.icon_of(unit))
			cell.tooltip_text = _unit_tooltip(unit) if tooltips else ""
		else:
			cell.hide_cell()
	cells_shown = count
	%Scroll.scroll_vertical = 0


func _show_groups() -> void:
	var by_tag := {}
	for unit in _units:
		var tag := str(unit.get("creature_tag"))
		if not by_tag.has(tag):
			by_tag[tag] = []
		by_tag[tag].append(unit)
	var tags: Array = by_tag.keys()
	tags.sort_custom(
		func(a: String, b: String) -> bool:
			var na: int = by_tag[a].size()
			var nb: int = by_tag[b].size()
			return na > nb or (na == nb and a < b)
	)
	_ensure_cells(tags.size())
	for i in _cells.size():
		var cell := _cells[i]
		if i < tags.size():
			var tag: String = tags[i]
			var group: Array = by_tag[tag]
			cell.show_group(tag, group, CreatureType.icon_of(group[0]))
			cell.tooltip_text = ("%s ×%d" % [_name_of(group[0]), group.size()]) if tooltips else ""
		else:
			cell.hide_cell()
	cells_shown = tags.size()
	%Scroll.scroll_vertical = 0


## The pool starts with `capacity` cells and only grows when more types are selected; the rows
## past the sixth scroll (the frame art has a fixed 2×6 grid).
func _ensure_cells(needed: int) -> void:
	var want := maxi(needed, capacity())
	%Cells.custom_minimum_size.y = (
		maxf(rows, rows + ceili(float(want - capacity()) / columns)) * cell_size.y
	)
	while _cells.size() < want:
		var cell: RosterCell = cell_scene.instantiate()
		cell.name = "Cell%d" % (_cells.size() + 1)
		cell.custom_minimum_size = cell_size
		cell.position = _slot_at(_cells.size())
		cell.visible = false
		cell.activated.connect(_on_cell_activated)
		%Cells.add_child(cell)
		_cells.append(cell)


func _show_ability() -> void:
	ability = (selection as _SELECTION).ability() if selection else null
	ability_tag = ability.tag if ability else ""
	var button: Button = %Ability
	button.visible = ability != null
	if ability == null:
		return
	var icon: Texture2D = ability.icon
	%AbilityIcon.texture = icon
	button.text = "" if icon else ability_tag
	button.tooltip_text = ability.display_name if tooltips else ""


## Click on a cell. By creature: plain = only that one, Shift = take it out, Ctrl = every selected
## creature of its type. By type: plain = only that type, Shift = take the type out.
func _on_cell_activated(cell: RosterCell, shift: bool, ctrl: bool) -> void:
	if selection == null or cell.members.is_empty():
		return
	var members: Array = cell.members
	if mode == "unit" and ctrl and not shift:
		members = _units.filter(
			func(unit: Variant) -> bool:
				return is_instance_valid(unit) and str(unit.get("creature_tag")) == cell.tag
		)
	if shift:
		(selection as _SELECTION).remove(members)
	else:
		(selection as _SELECTION).select_only(members)


func _on_refresh() -> void:
	_update_visible()
	if not visible:
		return
	var started := Time.get_ticks_usec()
	min_health = -1.0
	for i in cells_shown:
		var cell := _cells[i]
		cell.refresh_bars()
		if cell.health_fraction >= 0.0 and (min_health < 0.0 or cell.health_fraction < min_health):
			min_health = cell.health_fraction
		if mode == "unit" and tooltips and cell.unit and is_instance_valid(cell.unit):
			cell.tooltip_text = _unit_tooltip(cell.unit)
	last_refresh_us = Time.get_ticks_usec() - started


## The local wizard arrived (MatchWorld.local_wizard_changed): the roster shows for its side.
func bind(wizard: WizardBody) -> void:
	local_slot = wizard.owner_slot if wizard != null else 0
	_update_visible()


func _update_visible() -> void:
	visible = local_slot > 0


func _summary() -> String:
	if count == 1 and is_instance_valid(_units[0]):
		return _unit_tooltip(_units[0])
	return "%d unidades" % count


static func _name_of(unit: Node) -> String:
	return (unit as UnitBody).display_name() if unit is UnitBody else str(unit.get("creature_tag"))


static func _unit_tooltip(unit: Node) -> String:
	var health: Node = unit.get_node_or_null("Health")
	var text := _name_of(unit)
	if health:
		text += " %d/%d" % [roundi(health.current), roundi(health.maximum)]
	return text
