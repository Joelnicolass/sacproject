class_name BenchBuilding
extends Resource

## A building of the map the bench puts on the field (RFC-053 053a, F370): the BuildingType's scene (BuildingType.scene()),
## `offset` meters (X, Z) from BenchRules.anchor, on the ground. A gravestone (grv3) has 0 health in its BLDG: the
## indestructible case. Debug only: the map's own buildings stay where the layout has them.

@export var building: BuildingType
## 0 = the neutral side 31 (the owner of every building of the map).
@export var slot := 0
@export var offset := Vector2.ZERO
@export var yaw_deg := 0.0
## > 0 replaces the BLDG's health (MapBuilding.max_health_override).
@export var max_health_override := 0.0
## The name BenchExpect calls it by. Empty: the BLDG tag.
@export var label := ""


func key() -> String:
	if not label.is_empty():
		return label
	return building.tag if building != null else "building"
