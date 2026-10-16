extends Node

## Agent only (022e4): turns look layers on or off in the match world, to compare with and without
## grass in the same frame: `layer_off` = layer index in %Look/Layers (3 = grass), after `delay` s.
## `toggle_back` turns it on again `back_after` s later (the hot on/off check of the classic paint).

@export var world: Node
@export var layer_off := 3
@export var delay := 2.0
@export var back_after := 0.0


func _ready() -> void:
	await get_tree().create_timer(delay).timeout
	var rig := world.get_node_or_null("Look")
	if rig == null:
		print("RFC022E4 no rig")
		return
	rig.call("set_layer_enabled", layer_off, false)
	print("RFC022E4 layer %d off" % layer_off)
	if back_after > 0.0:
		await get_tree().create_timer(back_after).timeout
		rig.call("set_layer_enabled", layer_off, true)
		print("RFC022E4 layer %d on" % layer_off)
