@tool
class_name MinimapView
extends Resource

## How the minimap behaves (RFC-037); the look is MinimapStyleSet. The zoom in play lives in the Minimap node.

## Radius of the circle at HUD scale 1, in HUD units (sacengine 80).
@export var radius_px := 80.0
## Start zoom: meters of the world per HUD unit (sacengine minimapZoom 2.7). More = sees more.
@export var zoom := 2.7
@export var min_zoom := 0.5
@export var max_zoom := 15.0
## One wheel notch multiplies or divides the zoom by this (037c).
@export var zoom_step := 1.15
## The center sits this many camera distances ahead of the followed wizard (sacengine 3.73).
@export var lead_factor := 3.73
## The map turns with the camera (up = where the camera looks). Off: north up, centered on the wizard.
@export var heading_up := true
## The compass gem sits this many HUD units inside the circle's edge, on the north side (sacengine 3).
@export var compass_inset := 3.0
