@tool
class_name PropPlanner
extends RefCounted

## Where a scatter's props go. Pure and deterministic, with no nodes: the same rules, ground,
## mask, keep-outs and weights always give the same spots. Every try rolls the same randoms whether
## it is kept or not, so changing one knob does not reshuffle the rest. Candidates come first, then
## they are planted from the hearts of the clusters outwards: big props take their room before
## small ones, and `max_count` cuts at the edges, not at random. PropScatter3D and PropScatter2D
## gather the inputs and plant the spots.

## The most tries one plan makes, whatever the area and spacing (a guard for the editor).
const MAX_TRIES := 4000000


## What stops a scatter with these inputs (empty = nothing): its configuration warnings.
static func problems(
	rules: PropScatterRules, ground: PropGround, variants: Array[PropVariant]
) -> PackedStringArray:
	var out := PackedStringArray()
	if rules == null:
		out.append("Set rules (a PropScatterRules).")
	if ground == null:
		out.append("Set ground (PropFlatGround, PropRayGround or the game's own PropGround).")
	if variants.is_empty():
		out.append("Add a variant (a PropVariant with a scene).")
	for index in variants.size():
		if variants[index] == null or variants[index].scene == null:
			out.append("Variant %d has no scene." % index)
	return out


## In the editor, marks the scene being edited as changed after a scatter or a clear of `node`, so
## the new children are saved. Nothing in a running game.
static func mark_edited(node: Node) -> void:
	if not Engine.is_editor_hint() or not node.is_inside_tree():
		return
	if node.get_tree().edited_scene_root == null:
		return
	# Looked up by name: EditorInterface is not in an exported game.
	var editor := Engine.get_singleton(&"EditorInterface")
	if editor != null:
		editor.call(&"mark_scene_as_unsaved")


## The spots for `rules` over `ground` (already begun), thinned by `mask` (already begun, or
## null), away from `keep_out` (PropKeepOut.discs) and picking variants by `weights` (one per
## variant; empty = variant 0 always).
static func plan(
	rules: PropScatterRules,
	ground: PropGround,
	mask: PropMask,
	keep_out: PackedVector4Array,
	weights: PackedFloat32Array
) -> Array[PropSpot]:
	var spots: Array[PropSpot] = []
	var area := ground.bounds()
	if rules == null or not area.has_area():
		return spots
	var rng := RandomNumberGenerator.new()
	rng.seed = rules.random_seed
	var noise := FastNoiseLite.new()
	noise.seed = rules.random_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0 / rules.cluster_size
	noise.fractal_octaves = 2
	var tries := int(area.get_area() / (rules.spacing * rules.spacing) * rules.tries)
	if tries > MAX_TRIES:
		push_warning(
			"PropPlanner: %d tries for this area and spacing, cut to %d" % [tries, MAX_TRIES]
		)
		tries = MAX_TRIES
	var threshold := 1.0 - rules.cover
	var cumulative := _cumulative(weights)
	var candidates: Array[PropSpot] = []
	for index in tries:
		var at := area.position + Vector2(rng.randf(), rng.randf()) * area.size
		var roll := rng.randf()
		var jitter := rng.randf_range(-1.0, 1.0)
		var angle := rng.randf() * TAU
		var pick := rng.randf()
		var welcome := ground.weight_at(at)
		if welcome <= 0.0:
			continue
		var clear := _clearance(at, keep_out)
		if clear <= 0.0:
			continue
		if mask != null:
			welcome *= mask.weight_at(at)
			if welcome <= 0.0:
				continue
		var depth := noise.get_noise_2dv(at) * 0.5 + 0.5
		var inside := smoothstep(threshold - rules.edge, threshold + rules.edge, depth)
		var chance := inside * rules.density + (1.0 - inside) * rules.lone_chance
		if roll >= chance * clear * welcome:
			continue
		var heart := smoothstep(threshold, threshold + 3.0 * rules.edge, depth)
		var size := lerpf(rules.scale_range.x, rules.scale_range.y, heart)
		size *= 1.0 + rules.scale_jitter * jitter
		size *= lerpf(1.0 - rules.keep_out_shrink, 1.0, clear)
		var spot := PropSpot.new()
		spot.at = at
		spot.scale = maxf(size, 0.01)
		spot.angle = angle if rules.random_rotation else 0.0
		spot.variant = _pick(cumulative, pick)
		spot.depth = depth
		candidates.append(spot)
	# Deepest first; ties keep the order of the tries (sort_custom is not stable by itself).
	var order := range(candidates.size())
	order.sort_custom(
		func(a: int, b: int) -> bool:
			var da := candidates[a].depth
			var db := candidates[b].depth
			return da > db or (da == db and a < b)
	)
	var largest := rules.scale_range.y * (1.0 + rules.scale_jitter)
	var cell := maxf(rules.spacing * largest, 0.001)
	var grid: Dictionary[Vector2i, PackedVector3Array] = {}
	for index: int in order:
		if spots.size() >= rules.max_count:
			break
		var spot := candidates[index]
		if not _has_room(grid, cell, rules.spacing, spot):
			continue
		var key := Vector2i(floori(spot.at.x / cell), floori(spot.at.y / cell))
		var taken: PackedVector3Array = grid.get(key, PackedVector3Array())
		taken.append(Vector3(spot.at.x, spot.at.y, spot.scale))
		grid[key] = taken
		spots.append(spot)
	return spots


## 0 inside a keep-out, 1 well away from all of them, a smooth step across each soft edge.
static func _clearance(at: Vector2, discs: PackedVector4Array) -> float:
	var clear := 1.0
	for disc in discs:
		var radius := disc.z
		var far := radius * (1.0 + disc.w)
		var distance := at.distance_to(Vector2(disc.x, disc.y))
		if distance <= radius:
			return 0.0
		if far > radius:
			clear = minf(clear, smoothstep(radius, far, distance))
	return clear


static func _has_room(
	grid: Dictionary[Vector2i, PackedVector3Array], cell: float, spacing: float, spot: PropSpot
) -> bool:
	var key := Vector2i(floori(spot.at.x / cell), floori(spot.at.y / cell))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var near: PackedVector3Array = grid.get(key + Vector2i(dx, dy), PackedVector3Array())
			for other in near:
				var room := spacing * (spot.scale + other.z) * 0.5
				if spot.at.distance_squared_to(Vector2(other.x, other.y)) < room * room:
					return false
	return true


static func _cumulative(weights: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var total := 0.0
	for weight in weights:
		total += maxf(weight, 0.0)
		out.append(total)
	if total <= 0.0:
		return PackedFloat32Array()
	for index in out.size():
		out[index] /= total
	return out


static func _pick(cumulative: PackedFloat32Array, roll: float) -> int:
	for index in cumulative.size():
		if roll < cumulative[index]:
			return index
	return maxi(cumulative.size() - 1, 0)
