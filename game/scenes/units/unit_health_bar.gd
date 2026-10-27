class_name UnitHealthBar
extends MeshInstance3D

## Floating bar over a body. Green for the local slot, red for anyone else. Reads the Health component's `changed`
## signal, so it works the same on server and clients. It is the only one that shows or hides itself: never over a
## dead body, nor over one a Sac Doctor has taken (carried or being pumped back to life).
## Ref: sacengine draws your own creatures' bars only while they are selected (renderer.d:3890).

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

var _health: Health
var _body: UnitBody
var _taken := false
var _own := false
var _selected := false
## The side set by bind / set_owner_slot; -1 until one is given.
var _owner_slot := -1


## The bar can get its side before it is in the tree (no seat to ask yet): it asks again when it enters.
func _ready() -> void:
	if _owner_slot >= 0:
		set_owner_slot(_owner_slot)


## `body`: the creature the bar floats over, if it can be taken by a doctor (the bar hides while it is).
func bind(health: Health, owner_slot: int, body: UnitBody = null) -> void:
	if _health and _health.changed.is_connected(_on_changed):
		_health.changed.disconnect(_on_changed)
	_health = health
	if _health:
		_health.changed.connect(_on_changed)
		_on_changed(_health.current, _health.maximum)
	if _body == null and body != null:
		_body = body
		_body.taken_changed.connect(_on_taken_changed)
		_taken = _body.is_taken()
	set_owner_slot(owner_slot)


func set_owner_slot(owner_slot: int) -> void:
	_owner_slot = owner_slot
	var local := MpLocalSeat.slot_of(self)
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
	var dead := _health != null and _health.is_dead()
	if only_when_selected:
		var alive := _health != null and float(_health.get("maximum")) > 0.0 and not dead
		visible = alive and _selected
		return
	visible = not dead and not _taken and (not _own or _selected or not own_only_when_selected)


func _on_changed(current: float, maximum: float) -> void:
	set_instance_shader_parameter("fraction", clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0)
	_refresh_visible()


func _on_taken_changed(taken: bool) -> void:
	_taken = taken
	_refresh_visible()
