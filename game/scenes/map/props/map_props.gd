extends Node3D

## The map content that is not a building or a creature: the player starts and the manafounts are nodes of the scene
## (Starts, Founts). This node hands the match rules down to their ManaSource children and, on a machine that draws
## nothing, frees the plants. The plants themselves are nodes of high_noon_layout.tscn (Plants, RFC-035 035d), placed
## once by tools/bake/bake_map_layout.gd (sacengine placeWidgets, state.d:31346) and edited in the editor from then on.

## The Plants node of the layout. Presentation only: a headless server or a client without meshes has no use for it.
@export var plants_root: Node3D


## Debug scenes swap `rules` on the scene root. The mana sources of the map read theirs in
## _ready, so they get the root's rules here, before any child is ready.
func _enter_tree() -> void:
	var rules: Variant = owner.get("rules") if owner else null
	if not rules is MatchRules:
		return
	for source in find_children("ManaSource", "Node3D", true, false):
		source.set("rules", rules)


func _ready() -> void:
	if plants_root != null and not BodyCatalog.loads_meshes():
		plants_root.queue_free()
