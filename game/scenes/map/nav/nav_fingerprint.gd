@tool
class_name NavFingerprint
extends RefCounted

## Hashes for the versioned navmesh (RFC-035 035f, R10). Pure functions; the editor warning (MapNavRegion) and
## tools/bake_nav.gd call the same ones, so a bake and a check cannot disagree on what the source is.

## Nodes of the map that feed the bake (their static colliders and children): the terrain, the buildings, the manafounts.
const GROUP := &"nav_source"
## Metadata key of the source hash inside the navmesh resource.
const META_SOURCE := &"source_hash"


## SHA-256 of what the bake reads, taken from the nodes as the scene stores them (before any _ready, so the editor and the
## tool see the same thing): the numbers, and per `nav_source` node its path, local transform (the turn is in it) and tag; the
## terrain glb by its bytes. `root` is the map root (the parent of the NavigationRegion3D).
## It does not cover the box sizes the catalog gives a building: bake again after changing a model.
static func source_hash(root: Node, settings: NavBakeSettings) -> String:
	var lines := PackedStringArray()
	lines.append("settings:%s" % (settings.fingerprint() if settings != null else "none"))
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
	var source := node.scene_file_path
	if source.ends_with(".glb") and FileAccess.file_exists(source):
		parts.append(FileAccess.get_sha256(source))
	return "|".join(parts)


## SHA-256 of the navmesh geometry: vertices, then each polygon in order.
static func mesh_hash(navmesh: NavigationMesh) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(navmesh.get_vertices().to_byte_array())
	for k in navmesh.get_polygon_count():
		context.update(navmesh.get_polygon(k).to_byte_array())
	return context.finish().hex_encode()
