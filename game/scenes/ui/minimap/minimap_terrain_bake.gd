@tool
class_name MinimapTerrainBake
extends Node

## RFC-037 037a: draws the map's ground seen from straight above, once, into a texture. Own 3D world (no plants,
## buildings, sky or fog), an orthographic camera over the mesh's bounding box, ambient light only. It draws nothing
## else and knows nothing of the minimap: `Minimap` reads `texture`, `origin_xz` and `side_m`.
##
## Image axes: x = world x, y = world z (top = smallest z), a view from above with +y toward the viewer.
## `world_to_uv` gives the texture coordinate of a world point.
## Run alone (F6) it shows the texture. On the dedicated server (headless) it does nothing.

## The texture is ready (or was drawn again).
signal baked

## Optional: a map ground whose mesh is drawn instead of the one in `ground` (the world scene points at %Terrain).
@export var terrain: MeshInstance3D
@export_group("Parts")
@export var viewport: SubViewport
## The mesh drawn: the map's terrain mesh (`terrain`) with the classic ground material (the minimap never shows a biome's PBR ground).
@export var ground: MeshInstance3D
@export var camera: Camera3D
## Shown only when this scene runs alone.
@export var preview: TextureRect
@export_group("Bake")
## Texels per side. 1024 over a 2560 m map = 2.5 m per texel.
@export_range(256, 4096, 256) var resolution := 1024
## The camera sits this far over the highest point of the mesh.
@export var camera_margin_m := 50.0

## ViewportTexture of the bake; null until `baked`.
var texture: Texture2D
## World x/z of the texture's top-left corner and the side of the square it covers, in meters.
var origin_xz := Vector2.ZERO
var side_m := 0.0

var _is_baked := false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if viewport == null or ground == null or camera == null:
		warnings.append("Asigná viewport, ground y camera.")
	return warnings


func _ready() -> void:
	if preview:
		preview.visible = not Engine.is_editor_hint() and get_tree().current_scene == self
	if Engine.is_editor_hint():
		return
	if DisplayServer.get_name() == "headless":
		if viewport:
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_bake_when_ready.call_deferred()


func is_baked() -> bool:
	return _is_baked


## Texture coordinate (0…1) of a world point.
func world_to_uv(point: Vector3) -> Vector2:
	if side_m <= 0.0:
		return Vector2.ZERO
	return (Vector2(point.x, point.z) - origin_xz) / side_m


## The terrain is a sibling that readies after this node; draw one frame later so its mesh is in place.
func _bake_when_ready() -> void:
	await get_tree().process_frame
	await bake()


## Frames the mesh and renders it once. Awaitable: it returns after the image is drawn.
func bake() -> void:
	if viewport == null or ground == null or camera == null:
		return
	if terrain != null and terrain.mesh != null:
		ground.mesh = terrain.mesh
		ground.transform = terrain.global_transform
	if ground.mesh == null:
		push_warning("MinimapTerrainBake: no hay malla de terreno que hornear.")
		return
	var box := ground.transform * ground.mesh.get_aabb()
	var center := box.get_center()
	side_m = maxf(box.size.x, box.size.z)
	origin_xz = Vector2(center.x, center.z) - Vector2.ONE * side_m * 0.5
	viewport.size = Vector2i(resolution, resolution)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = side_m
	var height := box.end.y + camera_margin_m
	camera.near = 0.1
	camera.far = height - box.position.y + camera_margin_m
	# Image right = world +x, image down = world +z, looking down.
	camera.transform = Transform3D(Basis(Vector3.RIGHT, Vector3(0.0, 0.0, -1.0), Vector3.UP), Vector3(center.x, height, center.z))
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	texture = viewport.get_texture()
	if preview:
		preview.texture = texture
	await RenderingServer.frame_post_draw
	_is_baked = true
	baked.emit()
