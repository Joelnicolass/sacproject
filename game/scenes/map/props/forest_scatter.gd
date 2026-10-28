@tool
class_name ForestScatter
extends Node3D

## The forests of a map (MapProps/Forest). «Scatter» plants `tree` scenes as saved children: groves
## from a noise (woods and clearings), big old trees in the heart of a grove and young ones at its
## edge, a few lone trees in the open, none on the paths, in the holes or near what is played around
## (the starts, the manafounts, the buildings). Each tree is a normal child after that: move, scale
## or delete it with the gizmo, or press «Scatter» again to replace them all (same seed and knobs,
## same forest). Trees are map props (collision, navmesh): bake the navmesh after a scatter. The
## land of the match picks their mesh (FloraField), never where they stand. A match whose rules turn
## `forest` off takes the trees away before it starts (`take_away`; the clients when BiomeLink tells
## them) and NavService bakes the navmesh again without them.

const GROUP := &"forest_scatter"

## The tree it plants (forest_tree.tscn or a scene that inherits it).
@export var tree: PackedScene = preload("res://scenes/map/props/forest_tree.tscn")
@export var forest_seed := 7
@export_group("Groves")
## Across of a typical grove.
@export_range(40.0, 800.0, 10.0, "suffix:m") var grove_size_m := 320.0
## How much of the land the groves take (0 none, 1 all of it).
@export_range(0.0, 1.0, 0.01) var cover := 0.3
## How soft the edge of a grove is: wider = more young trees thinning out into the open.
@export_range(0.01, 0.5, 0.01) var edge := 0.16
## Chance of a tree inside a grove (1 = as packed as `spacing_m` lets them).
@export_range(0.0, 1.0, 0.01) var density := 0.85
## Chance of a lone tree out of the groves.
@export_range(0.0, 0.2, 0.005) var lone_trees := 0.01
@export_group("Trees")
## Room between two trees of scale 1 (trunk to trunk); it grows with their scale.
@export_range(3.0, 40.0, 0.5, "suffix:m") var spacing_m := 10.0
## Scale of the youngest (grove edge) and of the oldest (grove heart).
@export var scale_range := Vector2(0.55, 1.7)
## Random part of the scale on top of the grove's.
@export_range(0.0, 0.5, 0.01) var scale_jitter := 0.18
## Into the ground (m), so a slope shows no root in the air.
@export_range(0.0, 3.0, 0.05, "suffix:m") var sink_m := 0.4
@export var max_trees := 2000
@export_group("Keep out")
@export_range(0.0, 200.0, 1.0, "suffix:m") var start_m := 70.0
@export_range(0.0, 200.0, 1.0, "suffix:m") var fount_m := 40.0
@export_range(0.0, 100.0, 1.0, "suffix:m") var building_m := 18.0
## Away from the path role of the ground (Terrain.ground_roles, A); 0 = trees grow on it too (the
## imported maps paint A over half their land, not only on the roads).
@export_range(0.0, 50.0, 1.0, "suffix:m") var path_m := 0.0
## Fewer trees on rock (Terrain.ground_roles, B): 1 = none on bare rock.
@export_range(0.0, 1.0, 0.05) var rock_thinning := 0.6
@export_group("")
@export_tool_button("Scatter", "Reload") var scatter_button := scatter
@export_tool_button("Clear", "Remove") var clear_button := clear


func _ready() -> void:
	add_to_group(GROUP)
	if Engine.is_editor_hint():
		return
	# The rules of the match (the closest ancestor with them; on the authority the setup is
	# already applied); a map opened alone keeps its forest.
	var ancestor := get_parent()
	while ancestor != null and not ancestor.get("rules") is MatchRules:
		ancestor = ancestor.get_parent()
	if ancestor != null and not (ancestor.get("rules") as MatchRules).forest:
		take_away()


## The match plays without the forest: every tree goes (collision, navmesh obstruction, mesh).
func take_away() -> void:
	if get_child_count() > 0:
		clear()
		get_tree().call_group(FloraField.GROUP, "dress_trees")
		print("forest: off for this match")


## Replaces the children with a new forest; returns how many trees it planted.
func scatter() -> int:
	var terrain := Terrain.of(self)
	if terrain == null or not terrain.is_loaded():
		push_warning("%s: no loaded Terrain in this map." % name)
		return 0
	clear()
	var owner_node := _scene_owner()
	var rng := RandomNumberGenerator.new()
	rng.seed = forest_seed
	var groves := FastNoiseLite.new()
	groves.seed = forest_seed
	groves.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	groves.frequency = 1.0 / grove_size_m
	groves.fractal_octaves = 2
	var roles := terrain.ground_roles.get_image() if terrain.ground_roles else null
	if roles != null and roles.is_compressed():
		roles.decompress()
	var keep_out := _keep_out()
	var area := terrain.bounds()
	var grid := {}
	var cell := spacing_m * scale_range.y
	var attempts := int(area.get_area() / (spacing_m * spacing_m) * 3.0)
	var threshold := 1.0 - cover
	# Candidates first, then planted from the heart of the groves outwards: the old trees take their
	# room before the young ones and the lone ones, and `max_trees` cuts at the edges, not at random.
	var candidates := []
	for attempt in attempts:
		var at := area.position + Vector2(rng.randf(), rng.randf()) * area.size
		var roll := rng.randf()
		var jitter := rng.randf_range(-1.0, 1.0)
		var yaw := rng.randf() * TAU
		if not terrain.is_on_ground(at.x, at.y):
			continue
		var clear_k := _clearance(at, keep_out)
		if clear_k <= 0.0 or _near_path(roles, area, at):
			continue
		var noise := groves.get_noise_2d(at.x, at.y) * 0.5 + 0.5
		var forest := smoothstep(threshold - edge, threshold + edge, noise)
		var chance := (forest * density + lone_trees * (1.0 - forest)) * clear_k
		chance *= 1.0 - rock_thinning * _role(roles, area, at).b
		if roll >= chance:
			continue
		var heart := smoothstep(threshold, threshold + 3.0 * edge, noise)
		var size := lerpf(scale_range.x, scale_range.y, heart) * (1.0 + scale_jitter * jitter)
		size = clampf(size * lerpf(0.75, 1.0, clear_k), scale_range.x * 0.8, scale_range.y * 1.2)
		candidates.append([noise, at, size, yaw])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var planted := 0
	for candidate: Array in candidates:
		if planted >= max_trees:
			break
		var at: Vector2 = candidate[1]
		var size: float = candidate[2]
		if not _room(grid, cell, at, size):
			continue
		var key := Vector2i(floori(at.x / cell), floori(at.y / cell))
		grid[key] = grid.get(key, []) + [Vector3(at.x, at.y, size)]
		var planted_tree := tree.instantiate() as Node3D
		planted_tree.name = "Tree%04d" % planted
		add_child(planted_tree)
		planted_tree.owner = owner_node
		var y := terrain.height_at(at.x, at.y) - sink_m * size
		planted_tree.global_transform = Transform3D(
			Basis(Vector3.UP, candidate[3]).scaled(Vector3.ONE * size), Vector3(at.x, y, at.y)
		)
		planted += 1
	print("%s: %d trees" % [name, planted])
	return planted


func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.free()


func _scene_owner() -> Node:
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		return get_tree().edited_scene_root
	return owner if owner else self


## [Vector2 at, radius] of what the forest keeps away from.
func _keep_out() -> Array:
	var spots := []
	var map := owner if owner else get_parent()
	for node in map.find_children("*", "Node3D", true, false):
		if is_ancestor_of(node):
			continue
		var radius := 0.0
		if node is PlayerStart:
			radius = start_m
		elif node is ManaSource or node is ManafountBody:
			radius = fount_m
		elif node is MapBuilding:
			radius = building_m
		if radius > 0.0:
			var at := (node as Node3D).global_position
			spots.append([Vector2(at.x, at.z), radius])
	return spots


## 0 inside a keep-out, 1 well away from all of them (a soft edge of 40 % of the radius).
func _clearance(at: Vector2, spots: Array) -> float:
	var k := 1.0
	for spot: Array in spots:
		var radius: float = spot[1]
		k = minf(k, smoothstep(radius, radius * 1.4, at.distance_to(spot[0])))
	return k


func _room(grid: Dictionary, cell: float, at: Vector2, size: float) -> bool:
	var key := Vector2i(floori(at.x / cell), floori(at.y / cell))
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for other: Vector3 in grid.get(key + Vector2i(dx, dz), []):
				var room := spacing_m * (size + other.z) * 0.5
				if at.distance_squared_to(Vector2(other.x, other.y)) < room * room:
					return false
	return true


func _role(roles: Image, area: Rect2, at: Vector2) -> Color:
	if roles == null:
		return Color(1, 0, 0, 0)
	var uv := (at - area.position) / area.size
	var px := Vector2i(
		clampi(int(uv.x * roles.get_width()), 0, roles.get_width() - 1),
		clampi(int(uv.y * roles.get_height()), 0, roles.get_height() - 1)
	)
	return roles.get_pixelv(px)


func _near_path(roles: Image, area: Rect2, at: Vector2) -> bool:
	if roles == null or path_m <= 0.0:
		return false
	var around := [Vector2.ZERO, Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	for offset: Vector2 in around:
		if _role(roles, area, at + offset * path_m).a > 0.15:
			return true
	return false
