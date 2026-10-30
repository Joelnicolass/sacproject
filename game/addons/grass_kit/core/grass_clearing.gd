@tool
class_name GrassClearing
extends Resource

## No grass around the nodes of a group: within `radius` of each, none; up to `radius + soft` it
## thins out. The field reads the group's nodes again every half second, so a building placed in
## play clears its ground. The game puts its spawn points, buildings or altars in a group; the kit
## never knows their classes.

## The group whose nodes clear the grass around them.
@export var group: StringName = &""
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m") var radius := 3.0
## Width of the edge where the grass thins out back to full.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m") var soft := 1.5
