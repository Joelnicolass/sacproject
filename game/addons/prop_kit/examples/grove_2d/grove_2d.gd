extends Node2D

## PropKit's 2D example: bushes scattered around a few walls, cutting a navmesh baked in zones
## (pixels). Left click twice: a path between the two points. C: clear the bushes around the
## mouse (only their zones bake again). R: a new grove (another seed). Godot batches the sprites
## itself, so there is no PropBatch here. A game presses «Scatter» and «Bake» in the editor
## instead; this example scatters when it starts, so its scene stays small.

## How far around the mouse C clears.
@export_range(4.0, 400.0, 1.0, "suffix:px") var clear_radius_px := 60.0

@export var scatter: PropScatter2D
@export var zones: PropNavZones2D
@export var hud: Label
@export var path_line: Line2D

var _start := Vector2.INF
var _path := PackedVector2Array()


func _ready() -> void:
	zones.applied.connect(func(_zones: PackedInt32Array) -> void: _show())
	if scatter.get_child_count() == 0:
		scatter.scatter()
	_show()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_click(get_global_mouse_position())
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_C:
			clear_at(get_global_mouse_position())
		elif key == KEY_R:
			new_grove()


## Frees the bushes within `clear_radius_px` of `at` and re-bakes only where they stood.
func clear_at(at: Vector2) -> int:
	var areas: Array[Rect2] = []
	var cleared := 0
	for prop: Node2D in scatter.get_children():
		if prop.global_position.distance_to(at) > clear_radius_px:
			continue
		areas.append(PropObstructions.area_of(prop, false, zones.obstruction_sides))
		prop.queue_free()
		cleared += 1
	if cleared > 0:
		zones.rebake(areas, false)
	return cleared


## Scatters a grove with the next seed and bakes again.
func new_grove() -> void:
	scatter.rules.random_seed += 1
	scatter.scatter()
	zones.rebake_all(false)
	_path.clear()
	path_line.points = _path


func _click(at: Vector2) -> void:
	if _start == Vector2.INF or not _path.is_empty():
		_start = at
		_path.clear()
	else:
		_path = NavigationServer2D.map_get_path(get_world_2d().navigation_map, _start, at, true)
		_start = Vector2.INF
	path_line.points = _path
	_show()


func _show() -> void:
	var lines := PackedStringArray()
	lines.append("Bushes: %d" % scatter.get_child_count())
	lines.append("Navmesh: %s" % zones.stats)
	if _start != Vector2.INF:
		lines.append("Path: click where it ends")
	lines.append("Left click x2: path   C: clear bushes   R: new grove")
	hud.text = "\n".join(lines)
