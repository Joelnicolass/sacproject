@tool
class_name WarpSnap
extends Node

## Makes a jump look like a jump on the clients. The server moves a body in one step (Teleport)
## and the position reaches the clients through the synchronizer; the MpReplicate of the body would glide
## it across the map. The server calls announce() after the move: every client lets that body follow the
## net position with no smoothing for `window_s`, then goes back to the normal. Only the public knob
## `interpolate_speed` of the addon is used. Take the child out and the body glides (a joke, not a bug).
## Ref: RFC-021c.

## The addon node that smooths the body. Obligatory.
@export var net: MpReplicate
## How long the smoothing stays off after a jump, enough for the position to arrive.
@export var window_s := 0.6
## Speed that makes the smoothing instant (alpha = 1 - exp(-speed * delta) is 1 for any frame).
@export var snap_speed := 1000000.0

var _normal_speed := 0.0
var _snapping := false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if net == null:
		warnings.append("Asigná en `net` el MpReplicate del cuerpo.")
	return warnings


## Server or solo, right after moving the body.
func announce() -> void:
	if MpKit.is_networked() and MpKit.is_server():
		_snap.rpc()


@rpc("authority", "call_remote", "reliable")
func _snap() -> void:
	if net == null or not is_inside_tree():
		return
	if not _snapping:
		_normal_speed = net.interpolate_speed
		_snapping = true
	net.interpolate_speed = snap_speed
	await get_tree().create_timer(window_s).timeout
	if net != null and is_instance_valid(net):
		net.interpolate_speed = _normal_speed
	_snapping = false
