extends Node3D

## RtsKit's 3D example: a field, your units (blue), a foe's (red) and your hero (gold, the retreat
## anchor). The kit's whole command rig is in the scene, wired in the inspector; this script only
## spawns the units and adds what is the example's own: F follows the hero / frees the camera, and a
## line says what is selected. The units' logic is RtsExampleWalker (walk straight to the spot).

const WALKER := preload("res://addons/rts_kit/examples/shared/example_walker.gd")

@export var own_units := 12
@export var foe_units := 6

@onready var camera: RtsCamera3D = $Camera
@onready var selection: RtsSelection = $Command/Selection
@onready var status: Label = $Hud/Status
@onready var units_root: Node3D = $Units

var hero: Node3D


func _ready() -> void:
	hero = spawn(Vector3(0, 0, -12), 1, &"hero", Color(1.0, 0.8, 0.2), 1.4)
	var hero_unit := RtsUnit.of(hero)
	hero_unit.tags = [&"anchor"]
	hero_unit.selectable = false
	for i in own_units:
		var kind := &"soldier" if i % 3 != 0 else &"archer"
		var tint := Color(0.3, 0.55, 1.0) if kind == &"soldier" else Color(0.45, 0.85, 1.0)
		spawn(Vector3(-10 + (i % 6) * 3.0, 0, -4 - floori(i / 6.0) * 3.0), 1, kind, tint)
	for i in foe_units:
		spawn(Vector3(-8 + i * 3.2, 0, 18), 2, &"raider", Color(1.0, 0.3, 0.25))
	selection.changed.connect(_on_selection_changed)
	_on_selection_changed(selection.units())


## A unit: a capsule on layer 2 with an RtsUnit, a selection ring and the example's walker.
func spawn(at: Vector3, slot: int, kind: StringName, tint: Color, height := 1.0) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "%s_%d" % [kind, units_root.get_child_count()]
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.6 * height
	shape.shape = capsule
	shape.position.y = 0.8 * height
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.5
	capsule_mesh.height = 1.6 * height
	mesh.mesh = capsule_mesh
	mesh.position.y = 0.8 * height
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	mesh.material_override = material
	body.add_child(mesh)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.7
	torus.outer_radius = 0.85
	ring.mesh = torus
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.4, 1.0, 0.5)
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_material
	ring.position.y = 0.05
	ring.visible = false
	body.add_child(ring)
	var center := Marker3D.new()
	center.position.y = 0.8 * height
	body.add_child(center)
	var unit := RtsUnit.new()
	unit.name = "RtsUnit"
	unit.owner_slot = slot
	unit.kind = kind
	unit.size = 1.0
	unit.center = center
	body.add_child(unit)
	var walker: RtsExampleWalker = WALKER.new()
	walker.unit = unit
	body.add_child(walker)
	units_root.add_child(body)
	body.global_position = at
	return body


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.physical_keycode != KEY_F:
		return
	if camera.mode == RtsCamera3D.Mode.FREE:
		camera.mode = RtsCamera3D.Mode.FOLLOW
		camera.set_follow(hero)
	else:
		camera.free_target = hero.global_position
		camera.mode = RtsCamera3D.Mode.FREE


func _on_selection_changed(units: Array[RtsUnit]) -> void:
	if units.is_empty():
		status.text = "Nothing selected"
	elif units.size() == 1:
		status.text = "1 %s" % units[0].kind
	else:
		status.text = "%d units" % units.size()
