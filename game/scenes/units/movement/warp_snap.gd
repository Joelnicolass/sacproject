@tool
class_name WarpSnap
extends Node

## Makes a jump look like a jump on the clients. The server moves a body in one step (Teleport) and its
## position reaches the clients through the MpActor of the body, which draws it a little in the past and
## would glide it across the map. The server calls announce() after the move: every client then tells the
## MpActor to jump to the server's pose (MpActor.snap()) instead of sliding there. Take the child out and the
## body glides (a joke, not a bug). Only the server writes the position; here nothing writes it.
## Ref: RFC-021c, plan 072 (GUIDE of the kit, snap).

## The MpActor of the body. Obligatory.
@export var net: MpActor


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if net == null:
		warnings.append("Asigná en `net` el MpActor del cuerpo.")
	return warnings


## Server or solo, right after moving the body.
func announce() -> void:
	if MpKit.is_networked() and MpKit.is_server():
		_snap.rpc()


@rpc("authority", "call_remote", "reliable")
func _snap() -> void:
	if net != null and is_inside_tree():
		net.snap()
