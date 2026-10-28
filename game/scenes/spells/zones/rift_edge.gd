class_name RiftEdge
extends Node3D

## The mouth of a Demonic Rift: an open cylinder that rises out of the ground while the wizard casts and while the rift opens, stays, and sinks
## away when it closes; the shader draws its flames dark. Presentation only, on every peer, from the zone's phase. It frees nothing and hurts
## nobody (RiftSpawner and RiftSpirit).

@export var zone: GroundZone
## The wall: a cylinder mesh child, standing on this node's origin (the node's height scale makes it rise out of the ground).
@export var wall: MeshInstance3D
## How fast the mouth comes out (share of its height a second) and how fast it goes in.
@export_range(0.1, 5.0, 0.1) var emerge_per_s := 0.5
@export_range(0.1, 5.0, 0.1) var vanish_per_s := 1.0

var _size := 0.0


## This moves by itself every frame, so physics interpolation must leave it alone.
func _init() -> void: physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _ready() -> void:
	set_process(zone != null and not Engine.is_editor_hint())
	visible = false


func _process(delta: float) -> void:
	if zone.phase == GroundZone.Phase.ENDING:
		_size = maxf(0.0, _size - vanish_per_s * delta)
	else:
		_size = minf(1.0, _size + emerge_per_s * delta)
	visible = _size > 0.001
	scale = Vector3(1.0, maxf(_size, 0.001), 1.0)
	if wall != null:
		wall.set_instance_shader_parameter(&"emerge", _size)
