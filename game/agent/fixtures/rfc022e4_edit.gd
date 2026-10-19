extends Node

## Agent only (022e4): edits the biome's palette and the shared type in memory, like the inspector
## does, and emits `changed` (the editor-live path of `GrassField`). Nothing is saved.

@export var world: Node
@export var at_s := 14.0


func _ready() -> void:
	await get_tree().create_timer(at_s).timeout
	var rig := world.get_node_or_null("Map/Look")
	var grass: GrassSet = rig.profile.grass if rig and rig.profile else null
	if grass == null or grass.palette == null:
		print("RFC022E4_EDIT no palette")
		return
	grass.palette.color_tip = Color(0.2, 0.5, 0.95)
	grass.palette.color_mid = Color(0.1, 0.25, 0.6)
	grass.palette.emit_changed()
	var type := grass.primary()
	type.tall_height_m = 0.9
	type.emit_changed()
	print("RFC022E4_EDIT palette tip -> blue, meadow tall 0.9")
