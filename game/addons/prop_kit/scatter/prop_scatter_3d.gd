@tool
class_name PropScatter3D
extends Node3D

## Plants props over a 3D ground as saved children: press «Scatter» in the inspector (or call
## `scatter()`), then move, scale or delete any of them with the gizmo like any node. «Scatter»
## again replaces them all (the same rules and seed give the same props); «Clear» removes them.
## Where and how many: `rules`, `ground` (the game's terrain, PropRayGround, PropFlatGround),
## `mask` and `keep_out`. What: `variants`. Every child of this node is a prop: anything else under
## it is replaced too. Not: drawing them cheaply (PropBatch3D) or the navmesh (PropNavZones3D).

## A scatter planted `count` props.
signal scattered(count: int)

@export var rules: PropScatterRules
@export var variants: Array[PropVariant] = []
@export var ground: PropGround
## Optional: a painted map that thins or forbids props.
@export var mask: PropMask
@export var keep_out: Array[PropKeepOut] = []
## The props' names are this and a number (stable, so a scene's diff stays readable).
@export var name_prefix := "Prop"
@export_tool_button("Scatter", "Reload") var scatter_button := scatter
@export_tool_button("Clear", "Remove") var clear_button := clear


func _get_configuration_warnings() -> PackedStringArray:
	return PropPlanner.problems(rules, ground, variants)


## Replaces the children with new props and returns how many. `scene_owner` owns them, so they are
## saved with its scene: by default the edited scene in the editor, else this node's owner (or
## this node). Keep-outs are looked for under that owner.
func scatter(scene_owner: Node = null) -> int:
	var setup := PropPlanner.problems(rules, ground, variants)
	if not setup.is_empty():
		push_error("%s: %s" % [name, " ".join(setup)])
		return 0
	if not is_inside_tree():
		push_error("%s: scatter() needs the node in the scene tree" % name)
		return 0
	var root := scene_owner if scene_owner != null else _scene_owner()
	clear()
	if not ground.begin(self):
		push_warning("%s: the ground is not ready (%s)" % [name, ground.resource_path])
		return 0
	if mask != null and not mask.begin(ground.bounds()):
		push_warning("%s: the mask's texture cannot be read" % name)
		return 0
	var discs := PropKeepOut.discs(keep_out, root, self)
	var spots := PropPlanner.plan(rules, ground, mask, discs, PropVariant.weights_of(variants))
	var planted := 0
	for spot in spots:
		var prop := variants[spot.variant].scene.instantiate() as Node3D
		if prop == null:
			push_error("%s: variant %d is not a Node3D scene" % [name, spot.variant])
			return planted
		prop.name = "%s%04d" % [name_prefix, planted]
		add_child(prop)
		prop.owner = root
		prop.global_transform = _transform_of(spot)
		planted += 1
	PropPlanner.mark_edited(self)
	scattered.emit(planted)
	return planted


## Frees every child.
func clear() -> void:
	if get_child_count() == 0:
		return
	for child in get_children():
		remove_child(child)
		child.free()
	PropPlanner.mark_edited(self)


func _transform_of(spot: PropSpot) -> Transform3D:
	var basis := Basis(Vector3.UP, spot.angle)
	if rules.align_to_normal > 0.0:
		var up := Vector3.UP.slerp(ground.normal_at(spot.at), rules.align_to_normal).normalized()
		if not up.is_equal_approx(Vector3.UP):
			basis = Basis(Quaternion(Vector3.UP, up)) * basis
	basis = basis.scaled(Vector3.ONE * spot.scale)
	var height := ground.height_at(spot.at) - rules.sink * spot.scale
	return Transform3D(basis, Vector3(spot.at.x, height, spot.at.y))


func _scene_owner() -> Node:
	if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
		return get_tree().edited_scene_root
	return owner if owner != null else self
