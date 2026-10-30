@tool
class_name ForestScatter
extends PropScatter3D

## The forests of a map (MapProps/Forest, an instance of forest.tscn): a PropKit scatter of
## forest_tree.tscn over the map's Terrain (TerrainGround), kept away from the starts, the
## manafounts and the buildings by their groups. «Scatter» plants the trees as saved children; each
## one is a normal child after that (move, scale or delete it with the gizmo). Trees are map props
## (collision, navmesh obstruction): bake the navmesh after a scatter. The land of the match picks
## their mesh (FloraField), never where they stand. A match whose rules turn `forest` off takes the
## trees away before it starts (`take_away`; the clients when BiomeLink tells them) and NavService
## bakes the navmesh again without them.

const GROUP := &"forest_scatter"


func _ready() -> void:
	add_to_group(GROUP)
	if Engine.is_editor_hint():
		return
	# The rules of the match (the closest ancestor with them; on the authority the setup is
	# already applied); a map opened alone keeps its forest.
	var ancestor := get_parent()
	while ancestor != null and not ancestor.get("rules") is MatchRules:
		ancestor = ancestor.get_parent()
	if ancestor != null and not (ancestor.get("rules") as MatchRules).forest:
		take_away()


## The match plays without the forest: every tree goes (collision, navmesh obstruction, mesh).
func take_away() -> void:
	if get_child_count() > 0:
		clear()
		get_tree().call_group(FloraField.GROUP, "dress_trees")
		if DebugLog.on(&"forest"):
			print("forest: off for this match")
