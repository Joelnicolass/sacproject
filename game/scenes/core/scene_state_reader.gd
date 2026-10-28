class_name SceneStateReader
extends RefCounted

## Reads the nodes a saved scene keeps (its paths, properties, shapes and marker positions) from its SceneState, so a rule can ask
## "how wide is this ring" without instantiating the scene: an instanced Area3D registers a physics object, even outside the tree,
## and that alone moves the simulation. The scene keeps 32-bit numbers; `mm` decodes a measure to the double the rules always read.
## What it does not do: decide which facts a scene means (BodyFacts, SacrificeFacts) or cache anything.


## Every node the scene saves, by path ("." is the root, "Ritual/Bounds/Ring" a descendant), each with its saved properties by name.
## An inherited scene reads its base first: the properties it overrides replace the base ones, the rest are kept.
static func nodes_of(state: SceneState) -> Dictionary:
	var nodes := {}
	var base := state.get_base_scene_state()
	if base != null:
		nodes = nodes_of(base)
	for index in state.get_node_count():
		# A PackedScene state names the root "." and its children "./Child".
		var path := String(state.get_node_path(index)).trim_prefix("./")
		var props: Dictionary = nodes.get(path, {})
		for slot in state.get_node_property_count(index):
			props[String(state.get_node_property_name(index, slot))] = state.get_node_property_value(index, slot)
		nodes[path] = props
	return nodes


## The shape of the CollisionShape3D the root's `prop` points at, or null.
static func shape(nodes: Dictionary, root: Dictionary, prop: String) -> Shape3D:
	if not root.has(prop):
		return null
	var props: Dictionary = nodes.get(String(root[prop]), {})
	return props.get("shape") as Shape3D


## The local position of the Marker3D the root's `prop` points at (zero when it is not saved or has no transform).
static func marker(nodes: Dictionary, root: Dictionary, prop: String) -> Vector3:
	if not root.has(prop):
		return Vector3.ZERO
	var props: Dictionary = nodes.get(String(root[prop]), {})
	var xform: Variant = props.get("transform")
	return (xform as Transform3D).origin if xform is Transform3D else Vector3.ZERO


## The radius of the sphere or cylinder the root's `prop` points at, in mm; `fallback` when the scene does not save it.
static func radius(nodes: Dictionary, root: Dictionary, prop: String, fallback: float) -> float:
	var found := shape(nodes, root, prop)
	if found is SphereShape3D:
		return mm((found as SphereShape3D).radius)
	if found is CylinderShape3D:
		return mm((found as CylinderShape3D).radius)
	return fallback


## Half the height of the cylinder the root's `prop` points at (how far it reaches up and down from its centre), in mm; `fallback`
## when the scene does not save a cylinder.
static func half_height(nodes: Dictionary, root: Dictionary, prop: String, fallback: float) -> float:
	var found := shape(nodes, root, prop)
	if found is CylinderShape3D:
		return mm((found as CylinderShape3D).height * 0.5)
	return fallback


## The scene instanced at the node the root's `prop` points at (a child saved as an instance of another scene), or null.
static func instance(state: SceneState, root: Dictionary, prop: String) -> PackedScene:
	if not root.has(prop):
		return null
	var wanted := String(root[prop])
	for index in state.get_node_count():
		if String(state.get_node_path(index)).trim_prefix("./") == wanted:
			return state.get_node_instance(index)
	return null


## The double a measure of at most 3 decimals had before the scene stored it in 32 bits.
static func mm(value: float) -> float:
	return roundi(value * 1000.0) / 1000.0
