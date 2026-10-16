extends Node

## Counts the look nodes of the world once it is up. Headless / dedicated must print 0.

func _ready() -> void:
	for i in 10:
		await get_tree().process_frame
	var count := _count(get_tree().root)
	print("look_nodes %d dedicated %s display %s" % [count, MpKit.is_dedicated(), DisplayServer.get_name()])
	get_tree().quit()


func _count(node: Node) -> int:
	var total := 1 if (node is LookRig or node is QualityApplier) else 0
	for child in node.get_children():
		total += _count(child)
	return total
