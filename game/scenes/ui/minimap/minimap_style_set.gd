@tool
class_name MinimapStyleSet
extends Resource

## The whole look of the minimap in one place (RFC-037). Editable in the inspector; the match never writes it.

@export_group("Icons")
@export var wizard: MinimapMarkerStyle
@export var creature: MinimapMarkerStyle
@export var altar: MinimapMarkerStyle
@export var manalith: MinimapMarkerStyle
@export var manafount: MinimapMarkerStyle
## A soul the viewer can use (no side or the viewer's), and one of the foe.
@export var soul: MinimapMarkerStyle
@export var soul_foe: MinimapMarkerStyle

@export_group("Ground")
## Under the baked terrain (sacengine 0, 65/255, 66/255).
@export var background_color := Color(0.0, 65.0 / 255.0, 66.0 / 255.0)
## Multiplies the baked terrain. The bake already keeps its brightest sand under white (ambient 0.7); 1 leaves it as baked.
@export var ground_tint := Color.WHITE

@export_group("Vision wedge")
@export var fov_color := Color(1.0, 1.0, 0.0)
@export_range(10.0, 180.0, 1.0) var fov_deg := 82.0
## Line width in HUD units (sacengine 0.5).
@export var fov_width := 0.5
