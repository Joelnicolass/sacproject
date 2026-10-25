extends Node

## Target of the method tracks of the c1-0 probe (stands in for ClipEvents): it only remembers the kinds fired, in order.
## The probe reads `fired` after each manual step of the AnimationTree. Deleted when c1 closes.

var fired: Array[String] = []


func fire(kind: String) -> void:
	fired.append(kind)
