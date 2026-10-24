extends Node3D

## The map content that is not a building or a creature: the player starts and the manafounts are nodes of the scene
## (Starts, Founts). This node hands the match rules down to their ManaSource children. The plants are not nodes: the
## Flora layer of the map's LookRig draws them from the map's FloraLayer nodes (RFC-054, 055d-d3).


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
