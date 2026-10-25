extends Node

var _frames := 0

func _ready() -> void:
	var err: Error = SacrificeFlow.join_lan("127.0.0.1")
	print("join ", err)
	if err != OK:
		get_tree().quit(1)

func _process(_dt: float) -> void:
	_frames += 1
	if _frames > 300:
		print("timeout")
		get_tree().quit(1)
