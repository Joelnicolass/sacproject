@tool
class_name NavFingerprint
extends RefCounted

## The map's part of the navmesh's fingerprint (MapNav.extra_fingerprint): what the bake parses
## besides the props, which PropKit fingerprints itself. Pure functions; the bake tool, the editor
## and a match call the same one, so they cannot disagree on what the source is.

## Nodes of the map that feed the bake (their static colliders and children): the terrain, the
## buildings, the manafounts. NavService puts the blockers the saved bake lacks (altars, towers) in
## it before a re-bake.
const GROUP := &"nav_source"


## SHA-256 of what the bake parses, per `nav_source` node under `root` (the map root): its path,
## local transform (the turn is in it) and tag; a Terrain by its heights (TerrainHeights.checksum:
## the pixels of its heights.png and void.png as imported). The bake numbers are PropKit's own
## fingerprint. It does not cover the box sizes the catalog gives a building: bake again after
## changing a model.
static func source_hash(root: Node) -> String:
	var lines := PackedStringArray()
	if root != null:
		_collect(root, "", lines)
	lines.sort()
	return "\n".join(lines).sha256_text()


static func _collect(node: Node, path: String, lines: PackedStringArray) -> void:
	if node.is_in_group(GROUP):
		lines.append(_describe(node, path))
	for child in node.get_children():
		_collect(child, "%s/%s" % [path, child.name], lines)


static func _describe(node: Node, path: String) -> String:
	var parts := PackedStringArray([path])
	var node3d := node as Node3D
	if node3d != null:
		parts.append(var_to_bytes(node3d.transform).hex_encode())
	parts.append(str(node.get("tag")))
	var ground := node as Terrain
	if ground != null:
		parts.append(str(ground.heights.checksum()) if ground.heights != null else "no heights")
	return "|".join(parts)
