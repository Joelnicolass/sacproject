class_name OrderRadial
extends Node

## The one owner of the `order_units` button in the world, and of the keys that open the radial menu.
## A short tap on `view` is the order of always (`MatchCommand.right_at`). Holding the button still for `layout.hold_s`
## (0.25 s) opens the radial menu where it was pressed; the entry the pointer is on when it is
## released runs AT THE PRESS POINT: an order entry gives that order there, a formation entry gives the right click of that point in
## that formation, in one submit. Releasing in the center cancels. Holding `order_menu` (Tab) the same time opens it at the pointer and releasing it runs the entry. `formation_1`..`formation_8`
## (Alt+1..8) store a formation of the catalog on the selection without the menu.
## The menu draws and picks; this node turns an entry into a call to MatchCommand. It knows no order rule.

enum Source { NONE, MOUSE, KEY }

@export_group("Sockets")
@export var menu: RadialMenu
## The Control that takes the clicks of the world (`%View`).
@export var view: Control
@export var command: MatchCommand
## The formations `formation_N` picks from (the Nth of the catalog, in the menu's order).
@export var catalog: FormationCatalog = preload("res://data/orders/formations.tres")

var _source := Source.NONE
var _right_down := false
var _held_s := 0.0
var _press_at := Vector2.ZERO
var _origin := Vector2.ZERO
var _pointer := Vector2.ZERO


func _get_configuration_warnings() -> PackedStringArray:
	if menu == null or view == null or command == null:
		return PackedStringArray(["Assign menu, view and command."])
	return PackedStringArray()


func _ready() -> void:
	if view:
		view.gui_input.connect(_on_view_event)
	if menu:
		menu.entry_chosen.connect(_on_entry_chosen)


func is_open() -> bool:
	return menu != null and menu.is_open()


## Seen before the world and the HUD: the pointer for the menu, and the formation keys (Alt+digit must not also pick a group).
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_pointer = (event as InputEventMouseMotion).position
		if is_open():
			menu.point_at(_pointer)
		return
	if WorldInput.blocked(self):
		return
	for i in catalog.formations.size() if catalog else 0:
		if i < 8 and event.is_action_pressed("formation_%d" % (i + 1), false, true):
			command.set_formation(catalog.formations[i].id)
			get_viewport().set_input_as_handled()
			return


func _process(delta: float) -> void:
	if menu == null:
		return
	if WorldInput.blocked(self):
		if is_open():
			menu.cancel()
		_reset()
		return
	var hold := menu.layout.hold_s if menu.layout else 0.25
	if _right_down and _source != Source.KEY:
		_held_s += delta
		if not is_open() and _held_s >= hold and not command.camera_dragged():
			_open(Source.MOUSE, _press_at)
	_poll_key(delta, hold)


## Tab (`order_menu`): held `hold` seconds opens the menu at the pointer, released runs the entry.
func _poll_key(delta: float, hold: float) -> void:
	var down := Input.is_action_pressed(&"order_menu")
	if down and _source == Source.NONE and not _right_down:
		_held_s += delta
		if _held_s >= hold:
			_open(
				Source.KEY,
				get_viewport().get_mouse_position() if _pointer == Vector2.ZERO else _pointer
			)
	elif not down and _source == Source.KEY:
		menu.point_at(_pointer)
		menu.confirm()
		_reset()
	elif not down and _source == Source.NONE and not _right_down:
		_held_s = 0.0


func _on_view_event(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var button := event as InputEventMouseButton
	if not button.is_action(&"order_units"):
		return
	if button.pressed:
		if _source == Source.KEY:
			return
		_right_down = true
		_held_s = 0.0
		_press_at = button.position
		_pointer = button.position
		return
	if not _right_down:
		return
	if is_open() and _source == Source.MOUSE:
		menu.point_at(button.position)
		menu.confirm()
	elif not command.camera_dragged():
		command.right_at(button.position)
	_reset()


func _open(source: Source, at: Vector2) -> void:
	_source = source
	_origin = at
	menu.open_at(
		at, menu.layout.center_icons.get(command.context_kind(at)) if menu.layout else null
	)
	menu.point_at(_pointer)


func _reset() -> void:
	_source = Source.NONE
	_right_down = false
	_held_s = 0.0


func _on_entry_chosen(entry: RadialEntry) -> void:
	match entry.action:
		RadialEntry.Action.CONTEXT:
			pass
		RadialEntry.Action.ARM_ORDER:
			command.order_at(String(entry.order), _origin)
		RadialEntry.Action.ORDER_NOW:
			if entry.order == &"retreat":
				command.retreat()
		RadialEntry.Action.ABILITY:
			command.use_ability()
		RadialEntry.Action.FORMATION:
			if entry.formation:
				command.order_in_formation(entry.formation.id, _origin)
