extends Node2D

## RtsKit's 2D example: the same rig as skirmish_3d on a top-down 2D map. Your units (blue), a foe's
## (red), your hero (gold, the retreat anchor). The kit's command rig is in the scene; this script
## spawns the units and says what is selected. F follows the hero / frees the camera. World units are
## pixels here, so the scene sets Orders' spacing and retarget range and the selection's radius in pixels.

const WALKER := preload("res://addons/rts_kit/examples/shared/example_walker.gd")

@export var own_units := 12
@export var foe_units := 6

@onready var camera: RtsCamera2D = $Camera
@onready var selection: RtsSelection = $Command/Selection
@onready var status: Label = $Hud/Status
@onready var units_root: Node2D = $Units

var hero: Node2D


func _ready() -> void:
	hero = spawn(Vector2(0, 250), 1, &"hero", Color(1.0, 0.8, 0.2), 22.0)
	var hero_unit := RtsUnit.of(hero)
	hero_unit.tags = [&"anchor"]
	hero_unit.selectable = false
	for i in own_units:
		var kind := &"soldier" if i % 3 != 0 else &"archer"
		var tint := Color(0.3, 0.55, 1.0) if kind == &"soldier" else Color(0.45, 0.85, 1.0)
		spawn(Vector2(-250 + (i % 6) * 90.0, 60 + floori(i / 6.0) * 80.0), 1, kind, tint)
	for i in foe_units:
		spawn(Vector2(-240 + i * 96.0, -260), 2, &"raider", Color(1.0, 0.3, 0.25))
	selection.changed.connect(_on_selection_changed)
	_on_selection_changed(selection.units())


## A unit: a circle on layer 2 with an RtsUnit, a selection ring and the example's walker.
func spawn(at: Vector2, slot: int, kind: StringName, tint: Color, radius := 16.0) -> Node2D:
	var body := StaticBody2D.new()
	body.name = "%s_%d" % [kind, units_root.get_child_count()]
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	body.add_child(shape)
	var disc := Polygon2D.new()
	disc.polygon = _circle(radius, 20)
	disc.color = tint
	body.add_child(disc)
	var ring := Line2D.new()
	ring.name = "Ring"
	ring.points = _circle(radius + 6.0, 28)
	ring.closed = true
	ring.width = 2.5
	ring.default_color = Color(0.4, 1.0, 0.5)
	ring.visible = false
	body.add_child(ring)
	var unit := RtsUnit.new()
	unit.name = "RtsUnit"
	unit.owner_slot = slot
	unit.kind = kind
	unit.size = radius * 2.4
	body.add_child(unit)
	var walker: RtsExampleWalker = WALKER.new()
	walker.unit = unit
	walker.speed = 160.0
	walker.arrive = 4.0
	body.add_child(walker)
	units_root.add_child(body)
	body.global_position = at
	return body


func _circle(radius: float, sides: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides:
		points.append(Vector2.RIGHT.rotated(TAU * i / sides) * radius)
	return points


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != KEY_F:
		return
	if camera.mode == RtsCamera2D.Mode.FREE:
		camera.mode = RtsCamera2D.Mode.FOLLOW
		camera.follow = hero
	else:
		camera.mode = RtsCamera2D.Mode.FREE


func _on_selection_changed(units: Array[RtsUnit]) -> void:
	if units.is_empty():
		status.text = "Nothing selected"
	elif units.size() == 1:
		status.text = "1 %s" % units[0].kind
	else:
		status.text = "%d units" % units.size()
