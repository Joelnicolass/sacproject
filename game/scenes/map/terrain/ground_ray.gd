class_name GroundRay
extends RefCounted

## The height of the first surface a straight-down physics ray finds over a point: land, but also roofs, altars and
## anything else on the layers of `mask` (units and wizards are left out through `exclude`). It is the one copy of that
## ray for projectiles, souls, flyers and spawners; each caller keeps its own answer for «nothing below» (`miss`).
## What it does NOT do: say how high the land is (TerrainShape.height_at: roofs do not count there).

## How far above and below the point the ray reaches.
const REACH_M := 500.0


## The y of the first surface under `at` (`from` only gives the physics world), `miss` when the ray hits nothing.
static func surface_y(from: Node3D, at: Vector3, mask: int, exclude: Array[RID], miss: float) -> float:
	var hit := _cast(from, at, mask, exclude, REACH_M)
	return float(hit.position.y) if not hit.is_empty() else miss


## The point where the ray hits (x and z as the engine reports them, not rounded to `at`), null when it hits nothing.
## `reach_m` is how far above and below `at` the ray goes.
static func surface_point(from: Node3D, at: Vector3, mask: int, exclude: Array[RID], reach_m := REACH_M) -> Variant:
	var hit := _cast(from, at, mask, exclude, reach_m)
	return null if hit.is_empty() else hit.get("position")


## The bodies of every wizard in the tree: they share the ground layer and must not be the ground of a shot or a soul.
static func wizard_rids(tree: SceneTree) -> Array[RID]:
	var rids: Array[RID] = []
	for body in tree.get_nodes_in_group("wizard"):
		if body is CollisionObject3D:
			rids.append((body as CollisionObject3D).get_rid())
	return rids


static func _cast(from: Node3D, at: Vector3, mask: int, exclude: Array[RID], reach_m: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * reach_m, at + Vector3.DOWN * reach_m)
	query.collision_mask = mask
	query.exclude = exclude
	return from.get_world_3d().direct_space_state.intersect_ray(query)
