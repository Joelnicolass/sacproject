extends RefCounted

## Where the wizards of a map would stand: one PlayerStart per seat of the definition, each slot in
## 1..seats and unique, the spot `spawn_transform()` gives on land and on the navmesh, and every
## spot in the same walkable region (the seats can meet). Returns the problems; prints one line per
## start. Not: the altars and founts on land (MapGroundChecks), the walk from altar to fount
## (MapPathChecks).

## A spot this far from a walkable polygon counts as outside the navmesh.
const SNAP_M := 6.0


static func check(
	root: MapRoot, terrain: Terrain, definition: MapDefinition, nav: NavMeshBackend
) -> Array[String]:
	var problems: Array[String] = []
	var starts: Array[PlayerStart] = []
	for node in root.starts.get_children():
		if node is PlayerStart:
			starts.append(node as PlayerStart)
	if starts.size() != definition.player_starts:
		problems.append(
			(
				"%d PlayerStart nodes, the definition says %d seats"
				% [starts.size(), definition.player_starts]
			)
		)
	var seen := {}
	var shared_region := -2
	for start in starts:
		var path := root.get_path_to(start)
		if start.slot < 1 or start.slot > definition.player_starts or seen.has(start.slot):
			problems.append("%s: slot %d is out of range or repeated" % [path, start.slot])
		seen[start.slot] = true
		var spot := start.spawn_transform().origin
		var on_ground := terrain.is_on_ground(spot.x, spot.z)
		var land := nav.nearest_free(spot) if nav.built else Vector3(NAN, NAN, NAN)
		var near := (
			not is_nan(land.x) and Vector2(land.x - spot.x, land.z - spot.z).length() <= SNAP_M
		)
		var region := nav.zones.index.component_at(land) if near else -1
		var region_size := nav.zones.index.component_area[region] if region >= 0 else 0.0
		print(
			(
				# gdlint: ignore=max-line-length
				"start %s slot %d: altar (%.0f, %.0f) wizard (%.0f, %.0f) ground %s, region %d of %.0f m²"
				% [
					path,
					start.slot,
					start.global_position.x,
					start.global_position.z,
					spot.x,
					spot.z,
					on_ground,
					region,
					region_size
				]
			)
		)
		if not on_ground:
			problems.append("%s: the wizard spot is off the land" % path)
		if region < 0:
			problems.append("%s: the wizard spot is not on the navmesh" % path)
		elif shared_region == -2:
			shared_region = region
		elif region != shared_region:
			problems.append(
				"%s: the wizard spot is in another walkable region than the first seat" % path
			)
	return problems
