@tool
class_name ScarMark
extends FxScene

## A mark an effect leaves on the ground (a burn under a blast, a crack where a rock lands). It sits
## in the effect's scene, where the mark should be (move it with the gizmo), and `mark()` asks the
## map's GroundScars to paint `texture` there. The effect says when: its own script, a signal wired
## in the scene, or `play` when the node is the root of a scene played with FxBus.broadcast_scene
## (every peer paints when it sees the effect; whoever joins later does not see the earlier ones).
## Presentation only: with no window (headless, dedicated server) it does nothing. It never touches
## the game rules. Every ScarMark in the tree is in GROUP: a mark that may still be painted
## (GroundScarsNet waits for them when a peer catches up).

const GROUP := &"scar_marks"

## The picture, one of the imported SCAR files (a pixel is 0.15625 m): `scar` a burn, `gscr` /
## `tscr` rock cracks, `oils` oil...
@export var texture: Texture2D
## Not painted when the ground under it is this far (m) from the mark (a bolt that bursts in the air
## leaves nothing). 0 = always.
@export_range(0.0, 40.0, 0.5, "suffix:m") var max_height_m := 0.0


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)


## Paints the mark where this node is. False when nothing was painted.
func mark() -> bool:
	return mark_at(global_position)


## Paints the mark at `point` (world), for an effect that knows its place only when it happens (the
## end of a bolt).
func mark_at(point: Vector3) -> bool:
	var scars := GroundScars.of(self)
	if scars == null:
		GroundScars.note("refused: the map has no active GroundScars (%s)" % name)
		return false
	return scars.stamp(texture, point, max_height_m)


## FxBus.broadcast_scene: this scene is the effect itself, played where the mark goes. Paints it and
## goes.
func play(_params: Dictionary) -> void:
	mark()
	queue_free()


## Plays the mark scene `scene` at `at` on every peer (one event, like any other effect). Empty
## scene: nothing.
static func broadcast(scene: PackedScene, at: Vector3) -> void:
	if scene != null:
		FxBus.broadcast_scene(scene, at, {})


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if texture != null
		else PackedStringArray(["Assign `texture` (the picture of the mark)."])
	)
