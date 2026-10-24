@tool
class_name FrogLook
extends Node

## The frog's picture, on every peer, from its replicated state: the falling frame while it falls, the jump's sixteen frames (30 a second)
## while it jumps, the sitting frame while it sits or is stuck to a body; and a croak on one jump in five. It does not move the frog nor
## decide when it jumps (FrogHop). A dedicated server or a headless run draws nothing.
## Ref: sacengine updateRainFrog, renderer.d:2500-2516 (animationFrame 11 falling, 0..15 jumping, 15 sitting).

@export var drop: ZoneDrop
@export var sprite: AtlasSprite
@export var croak: SoundEmitter3D
@export_range(0, 15) var falling_frame := 11
@export_range(0, 15) var sitting_frame := 15
@export_range(1.0, 120.0, 1.0, "suffix:/s") var frames_per_s := 30.0
@export_range(1, 20) var croak_one_in := 5

var _last := ZoneDrop.Status.FLYING
var _jumping := false
var _t := 0.0


func _ready() -> void:
	set_process(not Engine.is_editor_hint() and drop != null and sprite != null and DisplayServer.get_name() != "headless")


func _process(delta: float) -> void:
	if drop.status != _last:
		if _last == ZoneDrop.Status.RESTING and drop.status == ZoneDrop.Status.FLYING:
			_jumping = true
			_t = 0.0
			if croak != null and randi() % croak_one_in == 0:
				croak.play_once()
		_last = drop.status
	_t += delta
	sprite.frame = sitting_frame if drop.status != ZoneDrop.Status.FLYING else (mini(int(_t * frames_per_s), 15) if _jumping else falling_frame)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if drop != null and sprite != null else PackedStringArray(["Faltan la rana (ZoneDrop) y su sprite (AtlasSprite)."])
