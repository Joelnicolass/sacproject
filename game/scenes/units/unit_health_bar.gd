extends MeshInstance3D

## Floating bar over a body. Green for the local slot, red for anyone else. Reads the
## Health component's `changed` signal, so it works the same on server and clients.
## sacengine draws your own creatures' bars only while they are selected (renderer.d:3890).

@export var own_color := Color(0.2, 0.85, 0.25)
@export var enemy_color := Color(0.9, 0.18, 0.12)
## RFC-049 049c: the bar of an ally of the local slot (2v2), apart from the own green and the enemy red.
@export var ally_color := Color(0.25, 0.6, 0.95)
## Meters above the top of the body.
@export var lift := 0.45
@export var own_only_when_selected := true
## RFC-028b: a building's bar, shown only while StructureInspector holds it (any side) and never
## for a body without health (maximum ≤ 0).
@export var only_when_selected := false

var _health: Node
var _own := false
var _selected := false


func bind(health: Node, owner_slot: int) -> void:
	if _health and _health.changed.is_connected(_on_changed):
		_health.changed.disconnect(_on_changed)
	_health = health
	if _health:
		_health.changed.connect(_on_changed)
		_on_changed(float(_health.get("current")), float(_health.get("maximum")))
	set_owner_slot(owner_slot)


func set_owner_slot(owner_slot: int) -> void:
	var local := MpKit.local_slot()
	_own = owner_slot > 0 and owner_slot == local
	var ally := not _own and owner_slot > 0 and local > 0 and SideRelations.stance(local, owner_slot) == SideRelations.Stance.ALLY
	set_instance_shader_parameter("fill_color", own_color if _own else (ally_color if ally else enemy_color))
	_refresh_visible()


func set_selected(on: bool) -> void:
	_selected = on
	_refresh_visible()


func place_above(body_height: float) -> void:
	position.y = body_height + lift


func _refresh_visible() -> void:
	var dead := _health != null and bool(_health.call("is_dead"))
	if only_when_selected:
		var alive := _health != null and float(_health.get("maximum")) > 0.0 and not dead
		visible = alive and _selected
		return
	visible = not dead and (not _own or _selected or not own_only_when_selected)


func _on_changed(current: float, maximum: float) -> void:
	set_instance_shader_parameter("fraction", clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0)
	if only_when_selected:
		_refresh_visible()
