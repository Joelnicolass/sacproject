extends "res://debug/suite/zone_case_base.gd"

## Case of rules_suite (playtest 2026-10-26): a tree of the map stops a creature. A Persephone tree flattens the ground, so it has
## no box body; its `Trunk` cylinder (saved in its scene, a shape the dedicated server keeps) does. A Manahoar told to walk straight
## through the trunk never gets inside it, and a tree that falls lets it through.

const TREE := preload("res://scenes/structures/buildings/persephone_tree_2.tscn")
const WALK_TICKS := 240


func run(host: Node3D) -> Dictionary:
	begin(host, "TreeBlockCases")
	var out := {"tree_blocks": await _blocks()}
	finish()
	return out


func _blocks() -> Dictionary:
	var checks := {}
	var tree := TREE.instantiate() as MapBuilding
	_root.add_child(tree)
	await _frames(2)
	var trunk := tree.trunk
	var radius := (trunk.shape as CylinderShape3D).radius if trunk != null and trunk.shape is CylinderShape3D else 0.0
	checks["flat_with_trunk"] = tree.type.flattens_ground and radius > 0.0 and not trunk.disabled and tree.collision_layer == 1
	var center := Vector2(trunk.global_position.x, trunk.global_position.z) if trunk != null else Vector2.ZERO
	var unit := _unit("oham", Vector3(center.x - 20.0, 0.1, center.y), 3)
	await _frames(10)
	unit.engagement.walk(Vector3(center.x + 20.0, 0.0, center.y))
	var closest := INF
	for _i in WALK_TICKS:
		await _frames(1)
		closest = minf(closest, Vector2(unit.global_position.x, unit.global_position.z).distance_to(center))
	print("tree_block_cases: trunk radius %.2f, closest %.2f, end %s" % [radius, closest, unit.global_position])
	checks["never_inside_trunk"] = closest >= radius - 0.05
	checks["it_walked"] = unit.global_position.x > center.x - 20.0 + 5.0
	(tree.get_node("Health") as Health).damage(100000.0, 3)
	await _frames(2)
	checks["fallen_tree_lets_through"] = trunk.disabled and tree.collision_layer == 0
	unit.queue_free()
	tree.queue_free()
	await _frames(2)
	return _verdict("tree_blocks", checks)
