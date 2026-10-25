# meta-name: MpKit actor
# meta-description: needs MpActor + MpInput children; rules on the server, mp_sv_* / mp_all_* calls
# meta-default: false
extends _BASE_

@onready var net: MpActor = $MpActor
@onready var input: MpInput = $MpInput


func _physics_process(_delta: float) -> void:
	if not net.is_authority():
		return
	# The rules run here (server or solo). Read the owner's keys like Input:
	# var dir := input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")


## Runs on the server when the owner calls net.to_server(&"action", payload).
func mp_sv_action(payload: Dictionary) -> void:
	pass


## Runs on every peer when the server calls net.to_all(&"effect").
func mp_all_effect() -> void:
	pass
