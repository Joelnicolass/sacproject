@tool
extends RefCounted

## What the left button paints, from the selected node and the bar's tool: the canvas, its mode, the step's name and
## whether the stroke stays where it was pressed (raise and lower). Also which Terrain the cursor sits on: the node itself,
## or the map's for a FloraLayer. A tool with no canvas for that node gives null (the click selects as usual).
## Not: painting, the bar, undo. Static.

const Toolbar := preload("res://addons/terrain_tools/brush/brush_toolbar.gd")
const TerrainHistory := preload("res://addons/terrain_tools/terrain_history.gd")


## One answer: paint `mode` on `canvas`, named `label` in the undo history.
class Target extends RefCounted:
	var canvas: BrushCanvas
	var mode := 0
	var label := ""
	## Raise and lower: the stroke stays where it was pressed and follows the mouse up or down.
	var pinned := false


## What `tool` paints on `node` (Shift held or not), or null.
static func resolve(history: TerrainHistory, node: Node, tool: Toolbar.Tool, shift: bool) -> Target:
	var terrain := node as Terrain
	if terrain != null:
		match tool:
			Toolbar.Tool.RAISE:
				return _made(history.lattice(terrain), BrushStroke.Mode.RAISE, true)
			Toolbar.Tool.SMOOTH:
				return _made(history.lattice(terrain), BrushStroke.Mode.FLATTEN if shift else BrushStroke.Mode.SMOOTH, false)
			Toolbar.Tool.VOID:
				return _made(history.lattice(terrain), BrushStroke.Mode.FILL if shift else BrushStroke.Mode.VOID, false)
	# The roles (ROLE_*, on a Terrain) and flora (FLORA, on a FloraLayer) canvases come in 066c and 066d.
	return null


## The Terrain whose heights the cursor and the strokes sit on: the node, or the map's (MapRoot.terrain) above a FloraLayer.
static func ground_of(node: Node) -> Terrain:
	if node is Terrain:
		return node as Terrain
	if not (node is FloraLayer):
		return null
	var at := node.get_parent()
	while at != null and not (at is MapRoot):
		at = at.get_parent()
	return (at as MapRoot).terrain if at != null else null


static func _made(canvas: BrushCanvas, mode: int, pinned: bool) -> Target:
	var target := Target.new()
	target.canvas = canvas
	target.mode = mode
	target.label = canvas.label(mode)
	target.pinned = pinned
	return target
