class_name RtsCommandInput
extends Node

## The player's commands in the world, as a coordinator of small pieces it holds no rules for:
## RtsSelectInput (left button and box), RtsOrderButton (right button, and the optional menu it holds),
## RtsOrderInput (orders), RtsArmedCommand (what waits for a click), RtsGroupKeys (group keys),
## RtsPointer (pixels to world). Take a piece out and that command is gone; no piece needs a menu.
## It reads the command keys (`command_keys`: a command that aims is armed for the next left click,
## one that does not happens now), the formation keys (Alt+N: the selection keeps the Nth formation),
## and `rts_order` / `rts_select` bound to a key (they aim at the screen middle). It hands
## `local_slot` / `local_team` to the pieces that need them. With `install_keymap` it adds the kit's
## default actions the project lacks (RtsKeymap). A game's own keys (spells) stay in the game.

## The local player's command input (one per player screen).
const GROUP := &"rts_command_input"

## The player of this screen. Setting it sets it on the selection, the pointer and the orders.
@export var local_slot := 1:
	set(value):
		local_slot = value
		_share_slot()
## That player's team; -1 = `local_slot`.
@export var local_team := -1:
	set(value):
		local_team = value
		_share_slot()
## Adds the kit's InputMap actions the project lacks (RtsKeymap.install).
@export var install_keymap := true
## The group-set keys use Cmd on macOS (Ctrl elsewhere); off: Ctrl everywhere.
@export var command_on_macos := true
## InputMap action -> command id of the catalog.
@export var command_keys: Dictionary[StringName, StringName] = {
	&"rts_order_attack": &"attack",
	&"rts_order_guard": &"guard",
	&"rts_order_move": &"move",
	&"rts_order_retreat": &"retreat",
}
## `formation_action_prefix` + N (Alt+N) keeps the Nth formation of the catalog on the selection.
@export var formation_action_prefix := "rts_formation_"
@export var formation_keys := 8
@export var order_action: StringName = &"rts_order"
@export var select_action: StringName = &"rts_select"
@export_group("Pieces")
@export var selection: RtsSelection
@export var orders: RtsOrders
@export var pointer: RtsPointer
@export var armed: RtsArmedCommand
@export var state: RtsCommandState
@export var order_input: RtsOrderInput
@export var select_input: RtsSelectInput
@export var group_keys: RtsGroupKeys
@export var order_button: RtsOrderButton


func _enter_tree() -> void:
	if install_keymap:
		RtsKeymap.install(command_on_macos)


func _ready() -> void:
	add_to_group(GROUP)
	_share_slot()


## True while the camera counts the pointer as dragged.
func camera_dragged() -> bool:
	return pointer != null and pointer.camera_dragged()


func right_at(screen: Vector2, from_action := false, formation := &"") -> void:
	if order_input:
		order_input.right_at(screen, from_action, formation)


func left_at(screen: Vector2, shift := false, ctrl := false) -> void:
	if select_input:
		select_input.left_at(screen, shift, ctrl)


func context_kind(screen: Vector2) -> StringName:
	return order_input.context_kind(screen) if order_input else &""


## A command of the catalog from a key or a button: armed, or done now.
func run_command(command: StringName) -> void:
	if order_input:
		order_input.run_command(command)


func set_formation(id: StringName) -> void:
	if order_input:
		order_input.set_formation(id)


func _input(event: InputEvent) -> void:
	if RtsWorldInput.blocked(self) or event is InputEventMouseButton or event is InputEventMouseMotion:
		return
	if not event.is_pressed() or event.is_echo():
		return
	if _formation_key(event) or group_keys and group_keys.handle(event):
		get_viewport().set_input_as_handled()
		return
	for action: StringName in command_keys:
		if _pressed(event, action):
			run_command(command_keys[action])
			get_viewport().set_input_as_handled()
			return
	if _pressed(event, order_action) and pointer:
		right_at(pointer.action_pointer(), true)
	elif _pressed(event, select_action) and pointer:
		left_at(pointer.action_pointer())
	else:
		return
	get_viewport().set_input_as_handled()


## Alt+N: the Nth formation of the catalog. True when `event` was one.
func _formation_key(event: InputEvent) -> bool:
	var catalog := orders.formations if orders else null
	if catalog == null or order_input == null:
		return false
	for i in mini(catalog.formations.size(), formation_keys):
		if _pressed(event, StringName(formation_action_prefix + str(i + 1))):
			order_input.set_formation(catalog.formations[i].id)
			return true
	return false


func _pressed(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action, false, true)


func _share_slot() -> void:
	if not is_node_ready():
		return
	if selection:
		selection.local_slot = local_slot
	if orders:
		orders.local_slot = local_slot
	if pointer:
		pointer.local_slot = local_slot
		pointer.local_team = local_team
