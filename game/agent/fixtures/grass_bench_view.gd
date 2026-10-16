class_name GrassBenchView
extends Resource

## One fixed view of the grass bench (agent only). `eye` and `target` are (x, height above the
## ground, z): the bench puts them on the terrain, so the numbers stay valid if the heights are tuned.

@export var label := ""
## Where the wizard stands (map x, z) and which way he faces.
@export var spot := Vector2.ZERO
@export var yaw_deg := 0.0
@export var eye := Vector3.ZERO
@export var target := Vector3.ZERO
@export_range(20.0, 120.0, 1.0) var fov := 75.0
