@tool
extends EditorNode3DGizmoPlugin

## Editor only: draws where a PropScatter3D plants (its ground's outline) and how a PropNavZones3D
## cuts the world (its zones), so both can be placed by eye.


func _init() -> void:
	# On top: the lines lie on the ground, which would hide them.
	create_material("ground", Color(0.95, 0.95, 0.95), false, true)
	create_material("zones", Color(0.4, 0.7, 1.0), false, true)


func _get_gizmo_name() -> String:
	return "PropKit"


func _has_gizmo(node: Node3D) -> bool:
	return node is PropScatter3D or node is PropNavZones3D


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node := gizmo.get_node_3d()
	var to_local := node.global_transform.affine_inverse()
	var lines := PackedVector3Array()
	var scatter := node as PropScatter3D
	if scatter != null:
		if scatter.ground == null:
			return
		var outline := scatter.ground.editor_outline()
		var flat := scatter.ground as PropFlatGround
		var y := flat.height if flat != null else node.global_position.y
		for k in outline.size():
			var a := outline[k]
			var b := outline[(k + 1) % outline.size()]
			lines.append(to_local * Vector3(a.x, y, a.y))
			lines.append(to_local * Vector3(b.x, y, b.y))
		if not lines.is_empty():
			gizmo.add_lines(lines, get_material("ground", gizmo))
		return
	var zones := node as PropNavZones3D
	var grid := zones.grid()
	if grid.zone_count() == 0:
		grid = PropZoneGrid.new(zones.area, zones.zone_size)
	for zone in grid.zone_count():
		var rect := grid.zone_rect(zone)
		var corners := [
			rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y),
		]
		for k in 4:
			var a: Vector2 = corners[k]
			var b: Vector2 = corners[(k + 1) % 4]
			lines.append(to_local * Vector3(a.x, 0.0, a.y))
			lines.append(to_local * Vector3(b.x, 0.0, b.y))
	if not lines.is_empty():
		gizmo.add_lines(lines, get_material("zones", gizmo))
