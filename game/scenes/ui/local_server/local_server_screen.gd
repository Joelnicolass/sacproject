extends Control

## «Servidor local». A door with three buttons: create a server on this PC, join the one of a friend, or go back.
## It owns no state. The two views do the work (`local_host_view`, `local_join_view`); this node only shows one at a time.
## Apart from «Salas online»: no room server, no list, no UPnP.

@onready var _menu: Control = %LocalMenu
@onready var _host_view: Control = %LocalHostView
@onready var _join_view: Control = %LocalJoinView


func _ready() -> void:
	%CreateLocal.pressed.connect(_show.bind(_host_view))
	%JoinLocal.pressed.connect(_show.bind(_join_view))
	%LocalBack.pressed.connect(_on_menu)
	_host_view.back_requested.connect(_show.bind(_menu))
	_join_view.back_requested.connect(_show.bind(_menu))
	_show(_menu)


func _show(view: Control) -> void:
	for candidate: Control in [_menu, _host_view, _join_view]:
		candidate.visible = candidate == view


func _on_menu() -> void:
	# By path, like the room screens: the menu points to this screen.
	get_tree().change_scene_to_file(SacrificeFlow.boot_path)
