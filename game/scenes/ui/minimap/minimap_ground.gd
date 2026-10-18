extends Control

## RFC-037: the minimap's floor: the circle's background color and the baked terrain, turned and scaled by the
## Minimap's frame state. Drawn once per frame; the circle shape comes from the parent mask.

@export var minimap: Minimap


func _draw() -> void:
	if minimap == null or minimap.style == null or minimap.view == null:
		return
	var radius := minimap.radius()
	draw_circle(Vector2.ONE * radius, radius, minimap.style.background_color)
	var bake := minimap.terrain_bake
	if bake == null or bake.texture == null or bake.side_m <= 0.0:
		return
	draw_set_transform_matrix(minimap.world_transform())
	draw_texture_rect(bake.texture, Rect2(bake.origin_xz, Vector2.ONE * bake.side_m), false, minimap.style.ground_tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)
