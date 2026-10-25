@tool
class_name MinimapView
extends Resource

## How the minimap behaves (RFC-037); the look is MinimapStyleSet. The zoom in play lives in the Minimap node.

## Radius of the circle in canvas pixels of the 1280×720 base.
@export var radius_px := 96.0
## Meters of the world from the center to the edge of the circle at the start, and the closest and farthest the wheel goes.
@export var view_radius_m := 216.0
@export var min_radius_m := 40.0
@export var max_radius_m := 1200.0
## One wheel notch multiplies or divides the view radius by this (037c).
@export var zoom_step := 1.15
## The center sits this many camera distances ahead of the followed wizard (sacengine 3.73).
@export var lead_factor := 3.73
## The map turns with the camera (up = where the camera looks). Off: north up, centered on the wizard.
@export var heading_up := true
## The compass gem sits this many pixels inside the circle's edge, on the north side.
@export var compass_inset := 4.0
