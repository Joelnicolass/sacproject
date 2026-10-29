@tool
class_name PropScatter2D
extends Node2D

## Plants props over a 2D ground as saved children: press «Scatter» in the inspector (or call
## `scatter()`), then move, scale or delete any of them like any node. «Scatter» again replaces
## them all (the same rules and seed give the same props); «Clear» removes them. Distances in
## `rules` are pixels. Where and how many: `rules`, `ground` (PropFlatGround, or the game's own),
## `mask` and `keep_out`. What: `variants`. Every child of this node is a prop: anything else under
## it is replaced too. Not: the navmesh (PropNavZones2D). Godot batches 2D sprites by itself, so
## there is no 2D PropBatch.

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
		var prop := variants[spot.variant].scene.instantiate() as Node2D
		if prop == null:
			push_error("%s: variant %d is not a Node2D scene" % [name, spot.variant])
			return planted
		prop.name = "%s%04d" % [name_prefix, planted]
		add_child(prop)
		prop.owner = root
		prop.global_position = spot.at
		prop.global_rotation = spot.angle
		prop.global_scale = Vector2.ONE * spot.scale
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


func _scene_owner() -> Node:
	if Engine.is_editor_hint() and get_tree().edited_scene_root != null:
		return get_tree().edited_scene_root
	return owner if owner != null else self
