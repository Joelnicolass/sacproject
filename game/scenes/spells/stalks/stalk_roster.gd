class_name StalkRoster
extends Node

## The bodies the stalks of one Meanstalks have already caught: no body is caught twice by the same cast, whichever stalk reaches it.
## Server only. It does not choose a prey nor hold anybody (Stalk and StalkGrip do).

var _caught: Array[Node3D] = []


func has(body: Node3D) -> bool:
	return body != null and _caught.has(body)


## True when `body` was not in the list and now is.
func add(body: Node3D) -> bool:
	if body == null or _caught.has(body):
		return false
	_caught.append(body)
	return true
