extends RefCounted

## Case of rules_suite for the hover frame: the show/hide rules, the 48 px minimum, the side color and the projection of a
## real box. Uses a scratch camera and static body under `host`, removed at the end.


func run(host: Node3D) -> Dictionary:
	var failures: PackedStringArray = []
	var root := Node3D.new()
	host.add_child(root)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.global_position = Vector3(0.0, 2.0, 12.0)
	camera.current = true
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.1, 0.1, 0.1)
	shape.shape = box
	body.add_child(shape)
	root.add_child(body)
	body.global_position = Vector3(0.0, 2.0, 0.0)
	var rect := HoverFrameRules.screen_rect(camera, HoverFrameRules.world_corners(body))
	if rect.size.x <= 0.0 or rect.size.x >= 48.0:
		failures.append("small box should project under 48 px (got %s)" % rect.size)
	var fitted := HoverFrameRules.fit(rect, Vector2(48.0, 48.0), 4.0)
	if fitted.size.x < 48.0 or fitted.size.y < 48.0 or fitted.get_center().distance_to(rect.get_center()) > 0.01:
		failures.append("fit must reach 48x48 around the same center (got %s)" % fitted)
	camera.global_position = Vector3(0.0, 2.0, -12.0)
	camera.look_at(Vector3(0.0, 2.0, -20.0))
	if HoverFrameRules.screen_rect(camera, HoverFrameRules.world_corners(body)).size != Vector2.ZERO:
		failures.append("a box behind the camera must give an empty rect")
	var rules := HoverFrameRules
	if rules.should_show(body, &"corpse", false, false, true):
		failures.append("corpse must hide")
	if rules.should_show(body, &"enemy_unit", false, true, true):
		failures.append("a drag must hide")
	if not rules.should_show(body, &"enemy_unit", false, false, true):
		failures.append("a unit must show")
	if rules.should_show(body, &"enemy_building", false, false, false) or not rules.should_show(body, &"enemy_building", true, false, false):
		failures.append("buildings only show armed when buildings_idle is off")
	if rules.should_show(body, &"hud", false, false, true) or rules.should_show(null, &"enemy_unit", false, false, true):
		failures.append("hud and null must hide")
	var blue := Color(0.0, 0.5, 1.0)
	var red := Color.RED
	var building := preload("res://scenes/map/map_building.tscn").instantiate()
	building.set("owner_slot", 1)
	if rules.color_of(building, &"enemy_building", blue, red) != SideColors.side_color(1):
		failures.append("side color for slot 1")
	building.free()
	root.queue_free()
	return {"hover_frame": {"ok": failures.is_empty(), "failures": failures}}
