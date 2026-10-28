class_name GodFlora
extends Resource

## The plants of a god's land, by the role a map's FloraLayer paints (`FloraLayer.land_role`): the
## map says where trees, shrubs and ground cover grow, the god says which plants they are. The
## layer's `land_index` picks one of the role's list (wrapping), so a map with five shrub layers
## shows five kinds of the god's shrubs when it has them. A role the god has no plant for falls back
## to the next list (trees → shrubs → cover → shrubs). `trees` also dress the map's forest props
## (ForestScatter trees, FloraField.dress_trees). Presentation only.

enum Role { NONE, TREE, SHRUB, COVER }

@export var trees: Array[VegetationSpecies] = []
@export var shrubs: Array[VegetationSpecies] = []
@export var cover: Array[VegetationSpecies] = []


## The god's plant for `role` and `index`; null = none at all (the layer keeps its own species).
func pick(role: Role, index: int) -> VegetationSpecies:
	var order: Array = []
	match role:
		Role.TREE:
			order = [trees, shrubs, cover]
		Role.SHRUB:
			order = [shrubs, cover]
		Role.COVER:
			order = [cover, shrubs]
	for list: Array in order:
		if not list.is_empty():
			return list[posmod(index, list.size())]
	return null
