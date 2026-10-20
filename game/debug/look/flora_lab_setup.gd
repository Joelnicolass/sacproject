@tool
class_name FloraLabSetup
extends Resource

## RFC-054 054c (F382): one shortcut of debug/look/flora_lab.tscn: which map, which preset and the camera poses that
## check_tick walks. Poses are map coordinates; the heights are meters over the ground under each point.

@export var map_scene: PackedScene
@export var quality: LookQuality
## (x, height over the ground, z) of the eye of each pose.
@export var eyes: PackedVector3Array = PackedVector3Array()
## (x, height over the ground, z) of the point each pose looks at.
@export var targets: PackedVector3Array = PackedVector3Array()
## Shown in the metrics label.
@export var notes: PackedStringArray = PackedStringArray()
