@tool
extends PropFlatGround

## The 2D example's own ground: flat over `area`, but no bush on a wall. It reads the walls from the
## scene when a scatter begins (the RectangleShape2D children of the nodes of `walls_group`). A
## game's ground is a script like this one: it extends PropGround (or a kit ground) and answers
## from the game's own data.

## The group of the walls' bodies.
@export var walls_group: StringName = &"grove_walls"
## Room kept between a wall and a bush (px).
@export_range(0.0, 200.0, 1.0, "suffix:px") var margin_px := 24.0

var _walls: Array[Rect2] = []


func begin(scatter: Node) -> bool:
	_walls.clear()
	for wall in scatter.get_tree().get_nodes_in_group(walls_group):
		for child in wall.get_children():
			var shape := child as CollisionShape2D
			if shape == null or not shape.shape is RectangleShape2D:
				continue
			var size := (shape.shape as RectangleShape2D).size
			var center := shape.global_position
			_walls.append(Rect2(center - size * 0.5, size).grow(margin_px))
	return true


func weight_at(at: Vector2) -> float:
	for wall in _walls:
		if wall.has_point(at):
			return 0.0
	return super(at)
