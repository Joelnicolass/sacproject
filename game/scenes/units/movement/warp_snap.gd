@tool
class_name WarpSnap
extends Node

## Marks a jump on the server. The server moves a body in one step (Teleport) and its pose reaches
## the clients through the MpActor of the body, which draws it a little in the past and would glide
## it across the map. The server calls announce() right after writing the new pose: MpActor.snap()
## counts the teleport and it travels in the same packet as the pose (net_teleports), so every
## client jumps there instead of sliding. Nothing is sent from here and nothing runs on a client.
## Take the child out and the body glides (a joke, not a bug).

## The MpActor of the body. Obligatory.
@export var net: MpActor


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if net == null:
		warnings.append("Assign to `net` the body's MpActor.")
	return warnings


## Server or solo, right after moving the body. A client does nothing: the server's mark reaches it
## with the pose.
func announce() -> void:
	if net != null and net.is_authority():
		net.snap()
