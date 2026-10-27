extends Node

## Agent only (022e4 hill pass): puts the local wizard on a hillside, so the fixed game camera
## looks at the grass on a slope. With `search` it prints the slopes around the wizard
## (`RFC022E4_SLOPE x z slope_deg height`) to pick a spot; otherwise it teleports to `spot`.

@export var spot := Vector2.ZERO
@export var search := false
@export var settle_s := 6.0
@export var yaw_deg := 0.0


func _ready() -> void:
	await get_tree().create_timer(settle_s).timeout
	var wizard := get_tree().get_first_node_in_group("local_wizard") as Node3D
	var terrain := Terrain.of(self)
	if wizard == null or terrain == null:
		print("RFC022E4_SLOPE no wizard/terrain")
		return
	if search:
		var c := Vector2(wizard.position.x, wizard.position.z)
		print("RFC022E4_SLOPE wizard %.1f %.1f" % [c.x, c.y])
		for dz in range(-160, 161, 16):
			for dx in range(-160, 161, 16):
				var x := c.x + dx
				var z := c.y + dz
				var h: float = terrain.height_at(x, z)
				var hx: float = terrain.height_at(x + 4, z) - terrain.height_at(x - 4, z)
				var hz: float = terrain.height_at(x, z + 4) - terrain.height_at(x, z - 4)
				print("RFC022E4_SLOPE %.0f %.0f %.1f %.1f" % [x, z, rad_to_deg(atan(Vector2(hx, hz).length() / 8.0)), h])
		return
	var y: float = terrain.height_at(spot.x, spot.y)
	wizard.position = Vector3(spot.x, y + 0.3, spot.y)
	wizard.rotation.y = deg_to_rad(yaw_deg)
	print("RFC022E4_SLOPE teleported %.1f %.1f %.1f" % [spot.x, y, spot.y])
