class_name RiftRibbon
extends MeshInstance3D

## The trail of a spirit of a Demonic Rift: a ribbon that faces the camera along the last positions of the node it follows (one in every few
## ticks, 120 ticks back), as wide as that node is scaled. Presentation only: every peer draws its own, a headless process none. It moves
## nothing and hurts nobody.
## Ref: sacengine DemonicRiftSpirit.locations (state.d:3527-3529, renderer.d:2517-2598).

## The node whose positions it draws (a RiftSpirit); it keeps drawing from where that node is.
@export var follows: Node3D
@export_range(0.05, 3.0, 0.05, "suffix:m") var width_m := 0.6
@export_range(2, 240) var trail_ticks := 120
## One position in every `stride` is a point of the ribbon.
@export_range(1, 8) var stride := 3

var _history := PackedVector3Array()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	set_process(follows != null and DisplayServer.get_name() != "headless")
	set_physics_process(follows != null and not Engine.is_editor_hint())


func _physics_process(_delta: float) -> void:
	_history.insert(0, follows.global_position)
	if _history.size() > trail_ticks:
		_history.resize(trail_ticks)


func _process(_delta: float) -> void:
	var drawing := mesh as ImmediateMesh
	var camera := get_viewport().get_camera_3d()
	if drawing == null:
		return
	drawing.clear_surfaces()
	if camera == null or _history.size() < 2:
		return
	var count := ceili(float(_history.size()) / float(stride))
	drawing.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in count:
		var at := mini(i * stride, _history.size() - 1)
		var here := _history[at]
		var along := _history[maxi(at - stride, 0)] - here if i > 0 else here - _history[mini(stride, _history.size() - 1)]
		var side := along.cross(camera.global_position - here).normalized() * width_m * 0.5 * follows.scale.x
		var u := float(i) / float(maxi(count - 1, 1))
		drawing.surface_set_uv(Vector2(u, 0.0))
		drawing.surface_add_vertex(here - side)
		drawing.surface_set_uv(Vector2(u, 1.0))
		drawing.surface_add_vertex(here + side)
	drawing.surface_end()


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if follows != null else PackedStringArray(["Falta `follows`: el nodo que sigue la cinta."])
