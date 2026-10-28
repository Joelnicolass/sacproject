@tool
class_name MinimapStyleSet
extends Resource

## The whole look of the minimap in one place. Editable in the inspector; the match never writes it.

@export_group("Icons")
@export var wizard: MinimapMarkerStyle
@export var creature: MinimapMarkerStyle
@export var altar: MinimapMarkerStyle
@export var manalith: MinimapMarkerStyle
## The Shrine: the «+» of the sheet.
@export var shrine: MinimapMarkerStyle
@export var manafount: MinimapMarkerStyle
## A soul the viewer can use (no side or the viewer's), and one of the foe.
@export var soul: MinimapMarkerStyle
@export var soul_foe: MinimapMarkerStyle

@export_group("Ground")
## Under the baked terrain.
@export var background_color := Color(0.0, 65.0 / 255.0, 66.0 / 255.0)
## Multiplies the baked terrain. The target is 0.5 gray; the bake is already lit at ambient 0.7, so 0.5 / 0.7
## lands on that brightness. 1 leaves it as baked.
@export var ground_tint := Color(0.714, 0.714, 0.714)

@export_group("Vision wedge")
@export var fov_color := Color(1.0, 1.0, 0.0)
@export_range(10.0, 180.0, 1.0) var fov_deg := 82.0
## Line width in canvas pixels.
@export var fov_width := 0.6
