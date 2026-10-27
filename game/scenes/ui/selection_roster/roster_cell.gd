class_name RosterCell
extends Button

## One 41×38 hole of the selection roster (canvas pixels).
## It shows a creature icon and, when the creature has health or mana, two 2-px bars on its right:
## health at x = 38, mana at x = 41, both rising from y = 36. Group mode puts a digit count on the
## icon (a share of Σhealth / Σmax for the bars). It only presents: the click goes up as `activated`
## with the modifiers it was pressed with, and the roster decides what that means.
## Ref: renderer.d:4400-4466 renderSelectionRoster (sizes ×1.2).

signal activated(cell: RosterCell, shift: bool, ctrl: bool)

## The health bar color.
## Ref: sacobject.d:1155 healthColor.
@export_color_no_alpha var health_color := Color8(192, 0, 0)
## The mana bar color.
## Ref: sacobject.d:1156 manaColor.
@export_color_no_alpha var mana_color := Color8(0, 96, 192)
## Pixels a full bar is tall: 36 of the 38 of the cell.
@export var bar_height := 36.0

## What the cell stands for: the creature (unit mode) or its tag (group mode).
var unit: Node
var tag := ""
## Members of the group (group mode) or just `unit`.
var members: Array = []
## Fraction of the last bars shown, -1 while the creature has none (readable by flows).
var health_fraction := -1.0
var mana_fraction := -1.0
var count := 0

var _healths: Array = []
var _manas: Array = []
var _shift := false
var _ctrl := false


func _ready() -> void:
	%Health.color = health_color
	%Mana.color = mana_color
	gui_input.connect(_on_gui_input)
	pressed.connect(_on_pressed)


func show_unit(creature: Node, texture: Texture2D) -> void:
	unit = creature
	tag = str(creature.get("creature_tag"))
	members = [creature]
	count = 1
	_healths = [creature.get_node_or_null("Health")]
	_manas = [creature.get_node_or_null("ManaPool")]
	_show(texture, "")


## A group of creatures of the same type: `members` are the selected ones.
func show_group(type_tag: String, group: Array, texture: Texture2D) -> void:
	unit = null
	tag = type_tag
	members = group
	count = group.size()
	_healths = []
	_manas = []
	for member in group:
		_healths.append(member.get_node_or_null("Health"))
		_manas.append(member.get_node_or_null("ManaPool"))
	_show(texture, str(count))


func hide_cell() -> void:
	visible = false
	unit = null
	members = []
	_healths = []
	_manas = []
	tag = ""
	count = 0


## Reads Health / ManaPool of the members and sizes the bars.
func refresh_bars() -> void:
	var health := 0.0
	var health_max := 0.0
	var mana := 0.0
	var mana_max := 0.0
	for i in _healths.size():
		var h: Node = _healths[i]
		if h and is_instance_valid(h):
			health += float(h.current)
			health_max += float(h.maximum)
		var m: Node = _manas[i]
		if m and is_instance_valid(m):
			mana += float(m.current)
			mana_max += float(m.maximum)
	_set_bar(%Health, health, health_max)
	_set_bar(%Mana, mana, mana_max)
	health_fraction = clampf(health / health_max, 0.0, 1.0) if health_max > 0.0 else -1.0
	mana_fraction = clampf(mana / mana_max, 0.0, 1.0) if mana_max > 0.0 else -1.0


func _show(texture: Texture2D, digits: String) -> void:
	visible = true
	%Icon.texture = texture
	# Without the cache there is no icon: the tag stands in for it.
	text = "" if texture else tag
	%Count.text = digits
	%Count.visible = not digits.is_empty()
	refresh_bars()


func _set_bar(bar: ColorRect, value: float, maximum: float) -> void:
	if maximum <= 0.0:
		bar.visible = false
		return
	var height := bar_height * clampf(value / maximum, 0.0, 1.0)
	bar.visible = height > 0.0
	bar.position.y = bar_height - height
	bar.size.y = height


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		_shift = button.shift_pressed
		_ctrl = button.ctrl_pressed


func _on_pressed() -> void:
	activated.emit(self, _shift, _ctrl)
