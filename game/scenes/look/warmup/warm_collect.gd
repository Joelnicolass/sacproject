class_name WarmCollect
extends RefCounted

## What the warm-up draws, found by walking the typed resources under some roots (a god goes to its book, its spells, their scenes;
## a body scene to the `<name>_look.tscn` next to it): every mesh, every 3D material and every scene whose root is a look (BodyLook,
## FxScene), which is safe to instance because it simulates nothing. Adding content adds no line here.
## What it does not do: draw, instance or load files of its own (only the look scene of a body, BodyLook.of_body), or keep anything.

## Engine resources with nothing to draw under them: the walk stops there (they are big and hold no mesh or material).
const LEAVES: Array[StringName] = [&"Script", &"Texture", &"Image", &"AudioStream", &"Animation", &"AnimationLibrary",
		&"NavigationMesh", &"Font", &"Shape3D", &"Shape2D", &"Curve", &"Gradient"]

var meshes: Array[Mesh] = []
var materials: Array[Material] = []
var scenes: Array[PackedScene] = []

var _seen: Dictionary[int, bool] = {}


## Everything drawable under `roots` (Resources, Arrays or Dictionaries of them).
static func from_roots(roots: Array) -> WarmCollect:
	var found := WarmCollect.new()
	for root: Variant in roots:
		found._visit(root)
	return found


## How many things there are to draw.
func size() -> int:
	return meshes.size() + materials.size() + scenes.size()


## Meshes, then materials, then scenes: what ShaderWarmup draws, in order.
func items() -> Array:
	var all: Array = []
	all.append_array(meshes)
	all.append_array(materials)
	all.append_array(scenes)
	return all


func _visit(value: Variant) -> void:
	match typeof(value):
		TYPE_ARRAY:
			for item: Variant in value:
				_visit(item)
		TYPE_DICTIONARY:
			for key: Variant in value:
				_visit(key)
				_visit(value[key])
		TYPE_OBJECT:
			var resource := value as Resource
			if resource != null:
				_visit_resource(resource)


func _visit_resource(resource: Resource) -> void:
	var id := resource.get_instance_id()
	if _seen.has(id) or _is_leaf(resource):
		return
	_seen[id] = true
	if resource is PackedScene:
		_visit_scene(resource as PackedScene)
		return
	if resource is Mesh:
		meshes.append(resource as Mesh)
	elif _is_drawable(resource):
		materials.append(resource as Material)
	for property in resource.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.type in [TYPE_OBJECT, TYPE_ARRAY, TYPE_DICTIONARY]:
			_visit(resource.get(property.name))


## A scene is read from its saved state (nothing is instanced): its nodes' values, the scenes it instances and, for a body, its look.
func _visit_scene(packed: PackedScene) -> void:
	var state := packed.get_state()
	if state.get_node_count() == 0:
		return
	if _is_look(state):
		scenes.append(packed)
	_visit(BodyLook.of_body(packed))
	for node in state.get_node_count():
		_visit(state.get_node_instance(node))
		for i in state.get_node_property_count(node):
			_visit(state.get_node_property_value(node, i))


## True when the root of the scene is (or extends) BodyLook or FxScene.
static func _is_look(state: SceneState) -> bool:
	var script := _root_script(state)
	while script != null:
		if script == BodyLook or script == FxScene:
			return true
		script = script.get_base_script()
	return false


static func _root_script(state: SceneState) -> Script:
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"script":
			return state.get_node_property_value(0, i) as Script
	var base := state.get_node_instance(0)
	return _root_script(base.get_state()) if base != null and base.get_state().get_node_count() > 0 else null


## A material a 3D mesh can wear (not a particle process or a 2D one).
static func _is_drawable(resource: Resource) -> bool:
	if resource is BaseMaterial3D:
		return true
	var shader_material := resource as ShaderMaterial
	return shader_material != null and shader_material.shader != null and shader_material.shader.get_mode() == Shader.MODE_SPATIAL


static func _is_leaf(resource: Resource) -> bool:
	for leaf in LEAVES:
		if resource.is_class(leaf):
			return true
	return false
