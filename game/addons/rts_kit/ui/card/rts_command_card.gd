class_name RtsCommandCard
extends GridContainer

## A command panel of buttons, the classic RTS way to give orders with the mouse and no menu: one
## button per entry (RtsMenuEntry), its key shown next to its name. A button runs its entry with no
## point (RtsOrderInput.run_entry): a command that aims is armed for the next left click (attack,
## guard, move), one that does not happens now (retreat), a formation is kept by the selection.
## `entries` empty: one entry per command of the orders' catalog and per formation, with the keys of
## `command_input` (its `command_keys` and formation keys). Buttons never take keyboard focus, so the
## keys keep reaching the world.

## A button was pressed (after it ran its entry).
signal entry_pressed(entry: RtsMenuEntry)

@export var order_input: RtsOrderInput
## For the keys shown (and the default entries). Optional.
@export var command_input: RtsCommandInput
## The buttons, in order. Empty: built from the catalogs.
@export var entries: Array[RtsMenuEntry] = []
## Building from the catalogs: these command ids only, in this order (empty = every command).
@export var commands: Array[StringName] = []
@export var show_formations := true
@export var button_size := Vector2(112, 34)

var _buttons: Array[Button] = []


func _ready() -> void:
	rebuild()


## The entries the panel shows now.
func shown_entries() -> Array[RtsMenuEntry]:
	if not entries.is_empty():
		return entries
	var orders := order_input.orders if order_input else null
	if orders == null:
		return []
	var actions := {}
	if command_input:
		for action: StringName in command_input.command_keys:
			actions[command_input.command_keys[action]] = action
	var prefix := command_input.formation_action_prefix if command_input else "rts_formation_"
	return RtsMenuEntry.from_catalogs(
		orders.commands, orders.formations if show_formations else null, commands, actions, prefix
	)


## Builds the buttons again (after the entries or the catalogs changed).
func rebuild() -> void:
	for button in _buttons:
		button.queue_free()
	_buttons.clear()
	for entry in shown_entries():
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = button_size
		button.icon = entry.display_icon()
		var key := key_text(entry.hotkey_action)
		button.text = tr(entry.display_label()) + ("  [%s]" % key if not key.is_empty() else "")
		button.tooltip_text = button.text
		button.pressed.connect(_on_pressed.bind(entry))
		add_child(button)
		_buttons.append(button)


## The buttons, in order (a test reads them).
func buttons() -> Array[Button]:
	return _buttons.duplicate()


## The first key bound to `action`, as text ("A", "Alt+1"), or "".
static func key_text(action: StringName) -> String:
	if action == &"" or not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var code := key.keycode
		if code == KEY_NONE and key.physical_keycode != KEY_NONE:
			# The key printed at that place on this keyboard; headless has no keyboard layout.
			code = key.physical_keycode
			if DisplayServer.get_name() != "headless":
				var local := DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
				if local != KEY_NONE:
					code = local
		var parts := PackedStringArray()
		if key.command_or_control_autoremap:
			parts.append("Cmd" if OS.has_feature("macos") else "Ctrl")
		elif key.ctrl_pressed:
			parts.append("Ctrl")
		if key.alt_pressed:
			parts.append("Alt")
		if key.shift_pressed:
			parts.append("Shift")
		parts.append(OS.get_keycode_string(code))
		return "+".join(parts)
	return ""


func _on_pressed(entry: RtsMenuEntry) -> void:
	if order_input:
		order_input.run_entry(entry)
	entry_pressed.emit(entry)
