class_name RagdollBaker
extends RefCounted

## Gives a model scene the physical skeleton its body falls and hangs with: a
## `PhysicalBoneSimulator3D` "Ragdoll" under the model's Skeleton3D (the bodies come from
## RagdollBones), and the two exports of the root, `ragdoll` and `hang_bone` (the body without a
## joint, the one a carrier holds the creature by). Does NOT run in a match; the simulator stays
## disabled until RagdollDriver wakes it. With `variant_b` it also adds `Ragdoll/Hook` (a body that
## follows the carrier, no shape, no layers) and `Hook/Pin` (a joint with every axis locked); the
## driver points the Pin at the hang bone while the creature hangs. An edit made by hand inside
## "Ragdoll" survives: `add_to` is for a model without one, `complete` only fills what is missing.

const SIMULATOR_NAME := "Ragdoll"
const HOOK_NAME := "Hook"
const PIN_NAME := "Pin"


static func has_ragdoll(root: Node) -> bool:
	return _simulator(root) != null


## Bakes a fresh "Ragdoll" (the old one, if any, is replaced) and sets the exports. Returns how many
## bodies it has, -1 when the model has no skeleton.
static func add_to(root: Node, variant_b := false) -> int:
	var skeleton := _skeleton(root)
	if skeleton == null:
		return -1
	var old := _simulator(root)
	if old != null:
		root.set("ragdoll", null)
		root.set("hang_bone", null)
		root.set("hang_pin", null)
		skeleton.remove_child(old)
		old.free()
	var simulator := PhysicalBoneSimulator3D.new()
	simulator.name = SIMULATOR_NAME
	simulator.process_mode = Node.PROCESS_MODE_DISABLED
	skeleton.add_child(simulator)
	simulator.owner = root
	var count := RagdollBones.add_bodies(skeleton, simulator, root)
	complete(root, variant_b)
	return count


## Sets what the root misses (the exports, and the hook with `variant_b`) on a model that already
## has its "Ragdoll". True when something changed.
static func complete(root: Node, variant_b := false) -> bool:
	var simulator := _simulator(root)
	if simulator == null:
		return false
	var changed := false
	if root.get("ragdoll") != simulator:
		root.set("ragdoll", simulator)
		changed = true
	var hang := hang_bone(simulator)
	if hang != null and root.get("hang_bone") != hang:
		root.set("hang_bone", hang)
		changed = true
	if variant_b and hang != null and simulator.get_node_or_null(HOOK_NAME) == null:
		_add_hook(root, simulator, hang)
		changed = true
	_open_instances(simulator.get_parent(), root)
	return changed


## The root body of the physical skeleton: the one without a joint. Null when there is none.
static func hang_bone(simulator: Node) -> PhysicalBone3D:
	for body: PhysicalBone3D in simulator.find_children("*", "PhysicalBone3D", false, false):
		if body.joint_type == PhysicalBone3D.JOINT_TYPE_NONE:
			return body
	return null


## Saves `root` to `path` and reloads it to compare every body with what was in memory. "" when it
## is the same, else the problem.
static func save(root: Node, path: String) -> String:
	var simulator := _simulator(root)
	if simulator == null:
		return "no Ragdoll to save"
	var before := RagdollCheck.snapshot(simulator)
	var packed := PackedScene.new()
	if packed.pack(root) != OK or ResourceSaver.save(packed, path) != OK:
		return "could not save %s" % path
	return RagdollCheck.compare(before, path)


## The Hook follows the carrier (sync_to_physics) from the rest pose of the hang bone; the Pin holds
## it with every axis locked. Pin.node_b stays empty: RagdollDriver sets it only while the creature
## hangs.
static func _add_hook(root: Node, simulator: Node, hang: PhysicalBone3D) -> void:
	var hook := AnimatableBody3D.new()
	hook.name = HOOK_NAME
	hook.collision_layer = 0
	hook.collision_mask = 0
	hook.sync_to_physics = true
	hook.transform = hang.transform
	simulator.add_child(hook)
	hook.owner = root
	var pin := Generic6DOFJoint3D.new()
	pin.name = PIN_NAME
	hook.add_child(pin)
	pin.owner = root
	for axis in ["x", "y", "z"]:
		pin.set("linear_limit_%s/enabled" % axis, true)
		pin.set("linear_limit_%s/upper_distance" % axis, 0.0)
		pin.set("linear_limit_%s/lower_distance" % axis, 0.0)
		pin.set("angular_limit_%s/enabled" % axis, true)
		pin.set("angular_limit_%s/upper_angle" % axis, 0.0)
		pin.set("angular_limit_%s/lower_angle" % axis, 0.0)
	pin.node_a = NodePath("..")
	root.set("hang_pin", pin)


## A node added inside an instanced scene (the .glb) is only saved when the instance is "editable
## children".
static func _open_instances(from: Node, root: Node) -> void:
	var node := from
	while node != null and node != root:
		if not node.scene_file_path.is_empty():
			root.set_editable_instance(node, true)
		node = node.get_parent()


static func _skeleton(root: Node) -> Skeleton3D:
	var found := root.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null


static func _simulator(root: Node) -> PhysicalBoneSimulator3D:
	var skeleton := _skeleton(root)
	if skeleton == null:
		return null
	var found := skeleton.find_children(SIMULATOR_NAME, "PhysicalBoneSimulator3D", false, false)
	return found[0] as PhysicalBoneSimulator3D if not found.is_empty() else null
