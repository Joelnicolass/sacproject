class_name CommandInput
extends Node

## Routes the player's input in the world to the command that owns it (sacengine dagonBackend.d:947-1300). Keys: creature
## and spell keys (SpellCommand), group keys (GroupKeys), Ctrl+R / Ctrl+A arm attack / guard, Ctrl+Space retreats,
## Ctrl+Q / Shift+B uses the ability, the order and select actions work through the crosshair. Left button on %View: a spell,
## ability or order icon waiting for its target takes the click; otherwise it selects (click, or a box past
## `rect_threshold_px`). The right button belongs to OrderRadial (RFC-038) and the minimap to MinimapPointing.
## It decides nothing itself: every branch is one call to a command.

const _SELECTION := preload("res://scenes/orders/selection.gd")
const CREATURE_KEYS := 11
const SPELL_KEYS := 11

## sacengine rectangleThreshold.
@export var rect_threshold_px := 3.0
@export var armed: ArmedCommand
@export var ray: PointerRay
@export var spells: SpellCommand
@export var abilities: AbilityCommand
@export var orders: OrderCommand
@export var group_keys: GroupKeys

@onready var _selection: _SELECTION = %Selection
@onready var _inspector: StructureInspector = %Inspector

var _left_down := false
var _press_at := Vector2.ZERO
var _press_ctrl := false
var _rect := false


func _ready() -> void:
	%View.gui_input.connect(_on_view_event)


## True while a modal UI (pause, options) covers the world (WorldInput, RFC-031 031c) or the walk-order debug scene drives
## the world by itself. Silences the hotkeys and the actions on the world.
static func blocked(from: Node) -> bool:
	return from.get_tree().get_first_node_in_group("walk_order") != null or WorldInput.blocked(from)


func _input(event: InputEvent) -> void:
	if blocked(self) or event is InputEventMouseButton:
		return
	for i in CREATURE_KEYS:
		if event.is_action_pressed("creature_%d" % (i + 1), false, true):
			spells.summon(i)
			return
	for i in SPELL_KEYS:
		if event.is_action_pressed("spell_%d" % (i + 1), false, true):
			spells.arm_by_key(i)
			return
	if group_keys.handle(event):
		return
	if event.is_action_pressed("order_attack", false, true):
		armed.arm_order("attack")
	elif event.is_action_pressed("order_guard", false, true):
		armed.arm_order("guard")
	elif event.is_action_pressed("order_retreat", false, true):
		orders.retreat()
	elif event.is_action_pressed("use_ability", false, true):
		abilities.use()
	elif event.is_action_pressed("order_units"):
		orders.right_at(ray.action_pointer(), true)
	elif event.is_action_pressed("select"):
		left_at(ray.action_pointer(), false, false)


## The left click on a point of the screen: the armed command takes it, else it selects what is there.
func left_at(screen: Vector2, shift: bool, ctrl: bool) -> void:
	match armed.mode:
		"spell":
			spells.cast_at(screen)
		"structure":
			spells.structure_at(screen)
		"ability":
			abilities.click_at(screen)
		"attack", "guard", "move":
			orders.icon_at(screen)
		_:
			var unit := ray.unit_under(screen)
			var building := ray.building_first(screen) if unit == null else null
			if unit:
				_selection.click(unit, screen, shift, ctrl)
			elif building:
				# RFC-028b: a building shows its bar (StructureInspector); the selection stays.
				_inspector.inspect(building)
			elif not shift and not ctrl and ray.is_empty_at(screen):
				# RFC-025 3.2: a plain left click on the ground or on nothing drops the selection
				# (an armed icon never gets here; the original keeps it: dagonBackend.d:1171-1198).
				_selection.clear()
				_inspector.clear()


func _on_view_event(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_left_down = true
				_press_at = button.position
				_press_ctrl = button.ctrl_pressed
				_rect = false
			elif _left_down:
				_left_down = false
				_release_left(button)
	elif event is InputEventMouseMotion and _left_down:
		var at := (event as InputEventMouseMotion).position
		if not _rect and not armed.is_armed() and not _press_ctrl and not ray.camera_dragged():
			_rect = absf(at.x - _press_at.x) >= rect_threshold_px or absf(at.y - _press_at.y) >= rect_threshold_px
		if _rect:
			_selection.show_box(_press_at, at)


func _release_left(button: InputEventMouseButton) -> void:
	if _rect:
		_rect = false
		_selection.select_rect(_press_at, button.position, button.shift_pressed)
		return
	if ray.camera_dragged():
		return
	left_at(button.position, button.shift_pressed, button.ctrl_pressed)
