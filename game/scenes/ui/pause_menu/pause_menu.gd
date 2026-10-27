extends CanvasLayer

## RFC-031 031b (F141): the pause menu. `pause_menu` (Esc) opens and closes it.
## - Alone the tree pauses (this layer runs with process_mode ALWAYS); online the match goes on and only the overlay
##   shows (the server and the other player are not stopped by one player's menu).
## - While open the node is in the group `WorldInput.MODAL`: the world input readers ask `WorldInput.blocked` and keep
##   quiet. The dim also eats the clicks on the world.
## - «Salir al menú» asks first, inside the same panel (Salir / Volver); then it unpauses and asks the session flow
##   (MpFlow.return_to_boot) to go back to the boot. A client leaves the server cleanly there (MpKit.leave), and the
##   server sees peer_left.
## «Opciones» (RFC-031 031c) opens the OptionsMenu child over this panel; Esc closes it first, then this menu.

signal opened
signal closed

const OPEN_GROUP := WorldInput.MODAL

## Title alone (the match is paused) and online (it is not).
@export var paused_title := "UI_PAUSE_MENU_PAUSED"
@export var online_title := "UI_PAUSE_MENU_ONLINE"
## Who looks at this screen: online the match goes on under the menu. Empty: it pauses as if alone.
@export var seat: MpLocalSeat

## True when this menu paused the tree, so only it unpauses it.
var _paused_here := false


func _ready() -> void:
	%Continue.pressed.connect(close)
	%Options.pressed.connect(%OptionsMenu.open)
	# The options overlay replaces this one while it is open (its own dim and panel; no double dim).
	%OptionsMenu.opened.connect(%Dim.hide)
	%OptionsMenu.closed.connect(_on_options_closed)
	%Quit.pressed.connect(_show_confirm.bind(true))
	%CancelQuit.pressed.connect(_show_confirm.bind(false))
	%ConfirmQuit.pressed.connect(_quit)


func _exit_tree() -> void:
	# `paused` outlives change_scene: never leave the next scene paused.
	_release_pause()


func is_open() -> bool:
	return is_in_group(OPEN_GROUP)


func open() -> void:
	if is_open():
		return
	add_to_group(OPEN_GROUP)
	var online := seat != null and seat.is_online()
	%PauseTitle.text = tr(online_title if online else paused_title)
	_show_confirm(false)
	%Dim.visible = true
	if not online and not get_tree().paused:
		get_tree().paused = true
		_paused_here = true
	opened.emit()


func close() -> void:
	if not is_open():
		return
	remove_from_group(OPEN_GROUP)
	%OptionsMenu.close()
	%Dim.visible = false
	_release_pause()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause_menu", false, true):
		return
	get_viewport().set_input_as_handled()
	if is_open():
		close()
	else:
		open()


func _on_options_closed() -> void:
	%Dim.visible = is_open()


func _show_confirm(asking: bool) -> void:
	%Main.visible = not asking
	%Confirm.visible = asking
	(%CancelQuit if asking else %Continue).grab_focus.call_deferred()


func _quit() -> void:
	close()
	_release_pause()
	var flow := MpFlow.find_in_tree(self)
	if flow == null:
		push_warning("PauseMenu: no hay MpFlow para volver al menú")
		return
	flow.return_to_boot()


func _release_pause() -> void:
	if _paused_here and is_inside_tree():
		get_tree().paused = false
	_paused_here = false
