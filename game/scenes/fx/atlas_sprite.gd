@tool
class_name AtlasSprite
extends MeshInstance3D

## One sprite of an atlas that faces the camera: a quad whose material (atlas_sprite_add or _mix)
## shows the cell `frame`. It cycles its cells by itself when `fps` says so; otherwise whoever
## animates it sets `frame`. It does not move or hurt. Its size is the quad's size times the node's
## scale. A headless or dedicated process draws nothing.

## The cell shown (left to right, then down).
@export var frame := 0:
	set(value):
		frame = value
		InstanceParams.set_on(self, &"frame", float(value))
## How much of the sprite shows (0 = none, 1 = all).
@export_range(0.0, 1.0, 0.01) var fade := 1.0:
	set(value):
		fade = value
		InstanceParams.set_on(self, &"fade", value)
## Cells a second when it plays on its own (0 = it does not), and how many cells it cycles through.
@export_range(0.0, 120.0, 0.5, "suffix:/s") var fps := 0.0
@export_range(1, 64) var cells := 16

var _t := 0.0


func _ready() -> void:
	set_process(
		fps > 0.0 and not Engine.is_editor_hint() and DisplayServer.get_name() != "headless"
	)


func _process(delta: float) -> void:
	_t += delta
	frame = int(_t * fps) % cells
