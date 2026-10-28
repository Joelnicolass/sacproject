extends Control

## One icon per thing on the map, in one `_draw` per frame (no node per creature). It reads the
## groups the game already keeps (wizard, unit, altar, structure, manafount, soul) and each kind's
## look from `minimap.style`. Dead or hidden foes are left out (is_targetable), your own things
## always show, souls take the viewer's color. What lies beyond the circle shows as an arrow at the
## edge only for your things and for wizards.
## Presentation only: the fog of war does not exist in the port, so everything shows.

@export var minimap: Minimap

## Measures for flows and checks: icons and arrows drawn last frame, microseconds the draw took, and
## where the local wizard's icon went (local canvas pixels; INF when it is not on the circle).
var icons_drawn := 0
var arrows_drawn := 0
var draw_us := 0
var local_wizard_icon := Vector2(INF, INF)
## Local unit direction the vision wedge points along last frame (ZERO when there is none).
var vision_direction := Vector2.ZERO

## Arrows to draw after the icons: [direction, color, style].
var _arrows: Array = []
## Side colors looked up this frame (a match has a handful of slots; 150 creatures ask for the same
## two).
var _side_colors := {}


func _draw() -> void:
	if minimap == null or minimap.style == null or minimap.view == null:
		return
	var started := Time.get_ticks_usec()
	var style := minimap.style
	var slot := minimap.local_slot
	icons_drawn = 0
	arrows_drawn = 0
	local_wizard_icon = Vector2(INF, INF)
	vision_direction = Vector2.ZERO
	_arrows.clear()
	_side_colors.clear()
	# The wedge is drawn under the icons: the apex does not paint over the wizard's own icon.
	_draw_vision()
	var tree := get_tree()
	for node in tree.get_nodes_in_group(Soul.GROUP):
		var soul := node as Soul
		if soul == null or not soul.state in [Soul.State.NORMAL, Soul.State.EMERGING]:
			continue
		var kind := style.soul if soul.color_for(slot) == Soul.SoulColor.BLUE else style.soul_foe
		_mark(soul, kind, 0, false)
	for node in tree.get_nodes_in_group(ManafountBody.GROUP):
		_mark(node as Node3D, style.manafount, 0, false)
	for node in tree.get_nodes_in_group(Altar.GROUP):
		_mark(
			node as Node3D,
			style.altar,
			int(node.get("owner_slot")),
			_is_mine(int(node.get("owner_slot")), slot)
		)
	for node in tree.get_nodes_in_group(CastTower.TOWER_GROUP):
		var tower := node as CastTower
		if tower == null:
			continue
		var owner_slot := tower.owner_slot
		if not _is_mine(owner_slot, slot) and tower.is_destroyed():
			continue
		var kind := style.shrine if tower.type.role == BuildingType.Role.SHRINE else style.manalith
		_mark(tower, kind, owner_slot, _is_mine(owner_slot, slot))
	for node in tree.get_nodes_in_group(UnitBody.GROUP):
		var unit := node as UnitBody
		if unit == null or not _unit_shows(unit, slot):
			continue
		_mark(unit, style.creature, unit.owner_slot, _is_mine(unit.owner_slot, slot))
	for node in tree.get_nodes_in_group(WizardBody.GROUP):
		var wizard := node as WizardBody
		if wizard == null or not _wizard_shows(wizard, slot):
			continue
		_mark(wizard, style.wizard, wizard.owner_slot, true)
	_draw_arrows()
	draw_us = Time.get_ticks_usec() - started


## The local slot and its allies (allied vision; there is no fog, so what changes is that an ally is
## shown always, with the arrow at the edge for its buildings).
func _is_mine(owner_slot: int, slot: int) -> bool:
	return (
		owner_slot == slot
		or (
			owner_slot > 0
			and slot > 0
			and SideRelations.stance(slot, owner_slot) == SideRelations.Stance.ALLY
		)
	)


func _unit_shows(unit: UnitBody, slot: int) -> bool:
	if _is_mine(unit.owner_slot, slot):
		return not unit.is_dead()
	return unit.is_targetable()


func _wizard_shows(wizard: WizardBody, slot: int) -> bool:
	return _is_mine(wizard.owner_slot, slot) or wizard.is_targetable()


## Draws `node`'s icon, or queues its arrow when it lies past the circle and `arrow_ok` (or the kind
## shows arrows for all).
func _mark(node: Node3D, kind: MinimapMarkerStyle, side_slot: int, arrow_ok: bool) -> void:
	if node == null or kind == null:
		return
	var radius := minimap.radius()
	var center := Vector2.ONE * radius
	var local := minimap.world_to_minimap(node.global_position)
	var offset := local - center
	var half := kind.size_px * 0.5
	var wants_arrow := kind.arrow_texture != null and (arrow_ok or kind.arrow_for_all)
	var limit := (0.92 * radius - half) if wants_arrow else (1.08 * radius + half)
	var color := _side_color(side_slot) if kind.use_side_color else kind.fixed_color
	if offset.length() <= limit:
		_draw_icon(local, kind, color)
		icons_drawn += 1
		if node is WizardBody and (node as WizardBody).is_local():
			local_wizard_icon = local
	elif wants_arrow and offset.length() > 0.001:
		_arrows.append([offset.normalized(), color, kind])


func _side_color(slot: int) -> Color:
	if not _side_colors.has(slot):
		_side_colors[slot] = SideColors.side_color(slot)
	return _side_colors[slot]


func _draw_icon(at: Vector2, kind: MinimapMarkerStyle, color: Color) -> void:
	var half := kind.size_px * 0.5
	if kind.texture != null:
		draw_texture_rect(
			kind.texture, Rect2(at - Vector2.ONE * half, Vector2.ONE * kind.size_px), false, color
		)
		return
	match kind.shape:
		MinimapMarkerStyle.Shape.TRIANGLE:
			draw_colored_polygon(
				PackedVector2Array(
					[at + Vector2(0.0, -half), at + Vector2(half, half), at + Vector2(-half, half)]
				),
				color
			)
		MinimapMarkerStyle.Shape.SQUARE:
			draw_rect(Rect2(at - Vector2.ONE * half, Vector2.ONE * kind.size_px), color)
		MinimapMarkerStyle.Shape.DIAMOND:
			draw_colored_polygon(
				PackedVector2Array(
					[
						at + Vector2(0.0, -half),
						at + Vector2(half, 0.0),
						at + Vector2(0.0, half),
						at + Vector2(-half, 0.0)
					]
				),
				color
			)
		_:
			draw_circle(at, half, color)


## Arrows sit just inside the edge (0.92 R minus 7 px), tip toward the thing.
func _draw_arrows() -> void:
	var radius := minimap.radius()
	var center := Vector2.ONE * radius
	for entry in _arrows:
		var direction: Vector2 = entry[0]
		var kind: MinimapMarkerStyle = entry[2]
		var at := center + direction * (0.92 * radius - 7.0)
		var half := kind.arrow_size_px * 0.5
		draw_set_transform(at, atan2(direction.x, -direction.y))
		draw_texture_rect(
			kind.arrow_texture,
			Rect2(Vector2.ONE * -half, Vector2.ONE * kind.arrow_size_px),
			false,
			entry[1]
		)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		arrows_drawn += 1


## Two lines from the local wizard along where it faces, `fov_deg` apart.
func _draw_vision() -> void:
	var wizard := _local_wizard()
	if wizard == null:
		return
	var apex := minimap.world_to_minimap(wizard.global_position)
	if (apex - Vector2.ONE * minimap.radius()).length() > minimap.radius() * 1.08:
		return
	var facing: Vector3 = wizard.facing_flat()
	var direction := minimap.world_dir_to_local(Vector2(facing.x, facing.z))
	vision_direction = direction
	var half_angle := deg_to_rad(minimap.style.fov_deg) * 0.5
	var length := minimap.radius() * 2.0
	for sign_value in [-1.0, 1.0]:
		var end := apex + direction.rotated(half_angle * sign_value) * length
		draw_line(apex, end, minimap.style.fov_color, minimap.style.fov_width, true)


func _local_wizard() -> WizardBody:
	for node in get_tree().get_nodes_in_group(WizardBody.GROUP):
		if node is WizardBody and (node as WizardBody).is_local():
			return node as WizardBody
	return null
