@tool
extends HBoxContainer

## The map brush's bar in the 3D editor's menu, shown while a Terrain or a FloraLayer is selected: which tool the left
## mouse button uses, in three groups (Relieve: raise and lower, smooth, void; Roles: grass, earth, rock, path; Flora:
## paint), and the knobs of the shared `brush` (a TerrainBrush .tres; another preset is another .tres): «Fuerza» only for
## raise and lower, «Flujo» for the pictures, «Densidad» for flora. Plus «Rearmar» while a stroke waits as a draft.
## Labels in Spanish. Not: painting (BrushPainter), what a tool paints on (BrushTargets).

signal rebuild_pressed

enum Tool { NONE, RAISE, SMOOTH, VOID, ROLE_OPEN, ROLE_EARTH, ROLE_ROCK, ROLE_PATH, FLORA }
## What is selected: a Terrain shows Relieve and Roles, a FloraLayer shows Flora.
enum Kind { TERRAIN, FLORA }

const PICTURES: Array[Tool] = [Tool.ROLE_OPEN, Tool.ROLE_EARTH, Tool.ROLE_ROCK, Tool.ROLE_PATH, Tool.FLORA]

## The brush every tool shares. Its knobs here change it for this session; edit the .tres in the inspector to keep them.
@export var brush: TerrainBrush

var tool := Tool.NONE

@onready var _buttons: Dictionary = {Tool.NONE: %Off, Tool.RAISE: %Raise, Tool.SMOOTH: %Smooth, Tool.VOID: %Void,
		Tool.ROLE_OPEN: %RoleOpen, Tool.ROLE_EARTH: %RoleEarth, Tool.ROLE_ROCK: %RoleRock, Tool.ROLE_PATH: %RolePath,
		Tool.FLORA: %Flora}
@onready var _title: Label = %Title
@onready var _relief: Control = %Relief
@onready var _roles: Control = %Roles
@onready var _flora: Control = %FloraGroup
@onready var _size: SpinBox = %Size
@onready var _falloff: SpinBox = %Falloff
@onready var _shape: OptionButton = %Shape
@onready var _strength: SpinBox = %Strength
@onready var _flow: SpinBox = %Flow
@onready var _density: SpinBox = %Density
@onready var _strength_knob: Control = %StrengthKnob
@onready var _flow_knob: Control = %FlowKnob
@onready var _density_knob: Control = %DensityKnob
@onready var _rebuild: Button = %Rebuild
@onready var _status: Label = %Status


func _ready() -> void:
	for each: Tool in _buttons:
		(_buttons[each] as Button).pressed.connect(func() -> void:
			tool = each
			_show_knobs())
	if brush != null:
		_size.value = brush.size_m
		_falloff.value = brush.falloff
		_shape.selected = brush.shape
		_strength.value = brush.strength_m
		_flow.value = brush.flow
		_density.value = brush.density
	_size.value_changed.connect(func(value: float) -> void: brush.size_m = value)
	_falloff.value_changed.connect(func(value: float) -> void: brush.falloff = value)
	_shape.item_selected.connect(func(index: int) -> void: brush.shape = index as TerrainBrush.Shape)
	_strength.value_changed.connect(func(value: float) -> void: brush.strength_m = value)
	_flow.value_changed.connect(func(value: float) -> void: brush.flow = value)
	_density.value_changed.connect(func(value: float) -> void: brush.density = value)
	_rebuild.pressed.connect(rebuild_pressed.emit)
	show_draft(false)
	_show_knobs()


## Back to no tool (the mouse selects as usual).
func reset() -> void:
	tool = Tool.NONE
	(_buttons[Tool.NONE] as Button).button_pressed = true
	_show_knobs()


## Shows the groups for what is selected; a tool of a hidden group goes back to none.
func show_for(kind: Kind) -> void:
	var terrain := kind == Kind.TERRAIN
	_title.text = "Terreno:" if terrain else "Flora:"
	_relief.visible = terrain
	_roles.visible = terrain
	_flora.visible = not terrain
	if tool != Tool.NONE and not _group_of(tool).visible:
		reset()


## Shows «Rearmar» while a stroke waits as a draft.
func show_draft(waiting: bool) -> void:
	_rebuild.visible = waiting


## How long the selected ground takes to build again, and when a stroke does it.
func show_cost(ms: float, light: bool) -> void:
	if ms < 0.0:
		_status.text = "midiendo…"
	else:
		_status.text = "rearmar %.0f ms · %s" % [ms, "al soltar" if light else "al guardar"]


func _show_knobs() -> void:
	_strength_knob.visible = tool == Tool.RAISE
	_flow_knob.visible = PICTURES.has(tool)
	_density_knob.visible = tool == Tool.FLORA


func _group_of(each: Tool) -> Control:
	if each == Tool.FLORA:
		return _flora
	return _roles if PICTURES.has(each) else _relief
