extends Node3D

## The map content that is not a building or a creature: the player starts and the manafounts are nodes of the scene
## (Starts, Founts). This node hands the match rules down to their ManaSource children and, on a machine that draws
## nothing, frees the plants. The plants themselves are nodes of high_noon_layout.tscn (Plants, RFC-035 035d), placed
## once by tools/bake/bake_map_layout.gd (sacengine placeWidgets, state.d:31346) and edited in the editor from then on.

## The Plants node of the layout. Presentation only: a headless server or a client without meshes has no use for it.
@export var plants_root: Node3D


## Debug scenes swap `rules` on the match root. The mana sources of the map read theirs in
## _ready, so they get the match's rules here, before any child is ready. The match is the closest ancestor with
## `rules` (the map is its child); a map opened alone has none and its sources keep theirs.
func _enter_tree() -> void:
	var rules: Variant = null
	var ancestor := get_parent()
	while ancestor != null and not ancestor.get("rules") is MatchRules:
		ancestor = ancestor.get_parent()
	if ancestor != null:
		rules = ancestor.get("rules")
	if not rules is MatchRules:
		return
	for source in find_children("ManaSource", "Node3D", true, false):
		source.set("rules", rules)


func _ready() -> void:
	if plants_root != null and not BodyLibrary.loads_meshes():
		plants_root.queue_free()
