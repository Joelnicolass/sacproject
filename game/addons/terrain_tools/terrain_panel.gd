@tool
extends VBoxContainer

## The ground's buttons in a Terrain's inspector, each handed to TerrainActions with this Terrain; the height of a new flat
## ground is the box beside its button. Labels in Spanish. Not: what the buttons do.

const TerrainActions := preload("res://addons/terrain_tools/terrain_actions.gd")

var terrain: Terrain
var actions: TerrainActions


func _ready() -> void:
	if terrain == null or actions == null:
		return
	(%OpenBlender as Button).pressed.connect(func() -> void: actions.open_in_blender(terrain))
	(%BringBlender as Button).pressed.connect(func() -> void: actions.bring_from_blender(terrain))
	(%Flat as Button).pressed.connect(func() -> void: actions.new_flat(terrain, (%FlatHeight as SpinBox).value))
	(%LevelBases as Button).pressed.connect(func() -> void: actions.level_bases(terrain))
	(%Validate as Button).pressed.connect(func() -> void: actions.validate(terrain))
