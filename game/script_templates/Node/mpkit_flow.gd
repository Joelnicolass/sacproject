# meta-name: MpKit session flow
# meta-description: extends MpFlow — host/join/1P and scene changes
# meta-default: false
extends MpFlow


func _ready() -> void:
	boot_path = "res://scenes/ui/boot.tscn"
	add_world(&"main", "res://scenes/world/match.tscn")
	# add_world(&"arena", "res://scenes/world/arena.tscn")
	super._ready()
