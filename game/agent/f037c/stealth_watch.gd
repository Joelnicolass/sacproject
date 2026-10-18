extends Node

## RFC-037 037c / risk R2: the unit's `_stealth` replicates to the clients.
## Server: a few seconds after the foe (the creature of another slot) exists, it puts it in stealth (`set_stealth`).
## Client: reads the replicated foe. `foe_was_visible` = it was first seen targetable; `foe_hidden` = later it is not targetable
## (what the minimap asks); `foe_fade` = the 3D transparency the setter applied on this peer.
## The flow `f037c_stealth_net.json` asserts these on the client.

@export var world: Node
@export var foe_slot := 2
@export var delay_s := 4.0

var foe_was_visible := false
var foe_hidden := false
var foe_stealth := false
var foe_fade := 0.0
var _seen_at := -1.0
var _stealthed := false


func _process(_delta: float) -> void:
	var foe := _foe()
	if foe == null:
		return
	if _seen_at < 0.0:
		_seen_at = Time.get_ticks_msec() / 1000.0
	if MpKit.is_server():
		if not _stealthed and Time.get_ticks_msec() / 1000.0 - _seen_at >= delay_s:
			_stealthed = true
			foe.call("set_stealth", true)
			print("STEALTH_NET server set stealth on ", foe.name)
		return
	var targetable := bool(foe.call("is_targetable"))
	if targetable and not foe_stealth:
		foe_was_visible = true
	foe_stealth = bool(foe.get("_stealth"))
	foe_hidden = foe_was_visible and not targetable
	var visual := foe.get_node_or_null("Tilt/Mesh") as GeometryInstance3D
	foe_fade = visual.transparency if visual else 0.0


func _foe() -> Node:
	for node in world.get_node("%Units").get_children():
		if int(node.get("owner_slot")) == foe_slot:
			return node
	return null
