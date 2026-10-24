class_name SlimeBall
extends Node3D

## The ball of slime that grows ten metres over a body while the wizard casts Slime and then falls on it. It is a presentation that FxBus
## plays on every peer (`play`), follows the body it was thrown at and frees itself when it lands (the state that lands is Slimed's). It does
## not apply the state nor splash: the Slimed state draws the splash when it goes on.
## Ref: sacengine SlimeCasting (sacobject.d:2602-2612, renderer.d:2208-2231).

## The ball, a 1 m sphere under this node.
@export var ball: MeshInstance3D
## How high it hangs over the body's centre while it grows, and the share of the cast it takes to grow before it falls.
@export_range(1.0, 30.0, 0.5, "suffix:m") var height_m := 10.0
@export_range(0.1, 0.99) var grow_share := 0.85

var _ticks := 1
var _tick := 0
var _target: Node3D


## FxBus.play_scene: `ticks` the cast lasts, `target` the path of the body.
func play(params: Dictionary) -> void:
	_ticks = maxi(1, int(params.get("ticks", 1)))
	_target = get_tree().root.get_node_or_null(NodePath(str(params.get("target", "")))) as Node3D
	set_physics_process(_target != null)
	if _target == null:
		queue_free()


func _physics_process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return
	_tick += 1
	var progress := float(_tick) / float(_ticks)
	var box := BodyNudge.box(_target)
	var center := box.get_center()
	var grown := clampf(progress / grow_share, 0.0, 1.0)
	var fall := clampf((progress - grow_share) / (1.0 - grow_share), 0.0, 1.0)
	global_position = center + Vector3.UP * height_m * (1.0 - fall)
	ball.scale = Vector3.ONE * box.size.length() * grown
	if progress >= 1.0:
		queue_free()
