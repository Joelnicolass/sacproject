@tool
extends HBoxContainer

## The ground brush's bar in the 3D editor's menu, shown while a Terrain is selected: which tool the left mouse button
## uses (none, raise and lower, smooth, void) and the knobs of the shared `brush` (a TerrainBrush .tres; another preset is
## another .tres), plus «Rearmar» while a stroke waits as a draft. Labels in Spanish. Not: painting (BrushPainter).

signal rebuild_pressed

enum Tool { NONE, RAISE, SMOOTH, VOID }

## The brush every tool shares. Its knobs here change it for this session; edit the .tres in the inspector to keep them.
@export var brush: TerrainBrush

var tool := Tool.NONE

@onready var _buttons: Dictionary = {Tool.NONE: %Off, Tool.RAISE: %Raise, Tool.SMOOTH: %Smooth, Tool.VOID: %Void}
@onready var _size: SpinBox = %Size
@onready var _falloff: SpinBox = %Falloff
@onready var _shape: OptionButton = %Shape
@onready var _strength: SpinBox = %Strength
@onready var _rebuild: Button = %Rebuild
@onready var _status: Label = %Status


func _ready() -> void:
	for each: Tool in _buttons:
		(_buttons[each] as Button).pressed.connect(func() -> void: tool = each)
	if brush != null:
		_size.value = brush.size_m
		_falloff.value = brush.falloff
		_shape.selected = brush.shape
		_strength.value = brush.strength_m
	_size.value_changed.connect(func(value: float) -> void: brush.size_m = value)
	_falloff.value_changed.connect(func(value: float) -> void: brush.falloff = value)
	_shape.item_selected.connect(func(index: int) -> void: brush.shape = index as TerrainBrush.Shape)
	_strength.value_changed.connect(func(value: float) -> void: brush.strength_m = value)
	_rebuild.pressed.connect(rebuild_pressed.emit)
	show_draft(false)


## Back to no tool (the mouse selects as usual).
func reset() -> void:
	tool = Tool.NONE
	(_buttons[Tool.NONE] as Button).button_pressed = true


## Shows «Rearmar» while a stroke waits as a draft.
func show_draft(waiting: bool) -> void:
	_rebuild.visible = waiting


## How long the selected ground takes to build again, and when a stroke does it.
func show_cost(ms: float, light: bool) -> void:
	if ms < 0.0:
		_status.text = "midiendo…"
	else:
		_status.text = "rearmar %.0f ms · %s" % [ms, "al soltar" if light else "al guardar"]
