class_name WarmKinds
extends RefCounted

## What a resource or a saved scene is to the warm-up's walk (WarmCollect): a leaf with nothing to draw under it, a material a 3D
## mesh can wear, a value that can hold more resources, or a scene safe to instance on the stage (a look: it simulates nothing).
## What it does not do: walk, load or keep anything (only the field names of each kind).

## Engine resources with nothing to draw under them: the walk stops there (they are big and hold no mesh or material).
const LEAVES: Array[StringName] = [&"Script", &"Texture", &"Image", &"AudioStream", &"Animation", &"AnimationLibrary",
		&"NavigationMesh", &"Font", &"Shape3D", &"Shape2D", &"Curve", &"Gradient"]

## A kind of resource (its script, or its engine class) -> its fields that can hold resources (`fields_of`).
static var _by_kind: Dictionary = {}


## True for the types that can hold a resource (the walk skips numbers, strings, vectors and packed arrays without a call).
static func holds(type: int) -> bool:
	return type == TYPE_OBJECT or type == TYPE_ARRAY or type == TYPE_DICTIONARY


static func is_leaf(resource: Resource) -> bool:
	for leaf in LEAVES:
		if resource.is_class(leaf):
			return true
	return false


## The stored properties of `resource`'s kind (its script, else its engine class) that can hold more resources, listed once per
## kind; null for a leaf. A shader's own parameters are only textures (leaves), so one list serves every ShaderMaterial. A mesh's
## `_surfaces` is left out: reading it copies every vertex back from the RenderingServer (its materials come from
## `surface_get_material`).
static func fields_of(resource: Resource) -> Variant:
	var script := resource.get_script() as Script
	var kind: Variant = script if script != null else StringName(resource.get_class())
	if _by_kind.has(kind):
		return _by_kind[kind]
	var fields: Variant = null
	if not is_leaf(resource):
		var names := PackedStringArray()
		for property in resource.get_property_list():
			var type: int = property.type
			if property.usage & PROPERTY_USAGE_STORAGE and holds(type) and not (resource is Mesh and property.name == "_surfaces"):
				names.append(property.name)
		fields = names
	_by_kind[kind] = fields
	return fields


## A material a 3D mesh can wear (not a particle process or a 2D one).
static func is_drawable(resource: Resource) -> bool:
	if resource is BaseMaterial3D:
		return true
	var shader_material := resource as ShaderMaterial
	return shader_material != null and shader_material.shader != null and shader_material.shader.get_mode() == Shader.MODE_SPATIAL


## True when the root of the scene is (or extends) BodyLook or FxScene, or when the scene is only engine geometry (a GeometryInstance3D
## root and no script anywhere, like a Label3D the code pools): neither simulates anything.
static func is_look(state: SceneState) -> bool:
	var script := _root_script(state)
	while script != null:
		if script == BodyLook or script == FxScene:
			return true
		script = script.get_base_script()
	return _is_bare_geometry(state)


static func _is_bare_geometry(state: SceneState) -> bool:
	if state.get_node_instance(0) != null or not ClassDB.is_parent_class(state.get_node_type(0), &"GeometryInstance3D"):
		return false
	for node in state.get_node_count():
		if state.get_node_instance(node) != null:
			return false
		for i in state.get_node_property_count(node):
			if state.get_node_property_name(node, i) == &"script":
				return false
	return true


static func _root_script(state: SceneState) -> Script:
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"script":
			return state.get_node_property_value(0, i) as Script
	var base := state.get_node_instance(0)
	return _root_script(base.get_state()) if base != null and base.get_state().get_node_count() > 0 else null
