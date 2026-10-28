class_name OrderLink
extends Node

## Connects the RtsKit orders (`orders`, an RtsOrders) to Sacrifice: who the local player is, where
## a retreat goes (the side's wizard), which foe an attack on a creature retargets to, and how a
## client's order reaches the server (MpKit's custom channel `rts_order`). The server, or a game
## with no network, applies an order at once. Units travel by their node name under `units_root`,
## any other body (a wizard, a building) by its path, so a big selection fits MpKit's 8 KB message.
## Not: the rules of an order (RtsOrders), what a creature does with one (UnitOrders).

const CHANNEL := &"rts_order"
## The prefixes of an id: a unit under `units_root`, or any other node by its absolute path.
const UNIT_ID := "u:"
const PATH_ID := "p:"

@export var orders: RtsOrders
## Where the creatures are (World/Units): an order names them by their node name.
@export var units_root: Node
## An attack on a creature makes each unit take the enemy creature nearest its own slot within this
## range (the original's 100 m).
@export var retarget_range := 100.0


func _ready() -> void:
	if orders == null:
		push_error("OrderLink: `orders` is empty.")
		return
	orders.retarget_range = retarget_range
	orders.local_slot = MpKit.local_slot()
	orders.send = _send
	orders.anchor_for = _wizard_of
	orders.closest_foe = _closest_enemy_creature
	MpKit.custom_received.connect(_on_custom)


## The command an attack on `target` is: `attack` on a creature (each unit retargets to the creature
## nearest its slot), `attack_body` on anything else (a wizard, a building: no retarget).
static func attack_command(target: Node) -> StringName:
	return &"attack" if target != null and target.is_in_group(UnitBody.GROUP) else &"attack_body"


func _send(order: RtsOrder) -> void:
	if MpAuthority.should_send_command():
		MpKit.send_custom(CHANNEL, {"order": order.to_array(_id_of)})
		return
	_apply(order, MpKit.local_slot())


func _on_custom(channel: StringName, data: Dictionary, from_peer: int) -> void:
	if channel != CHANNEL or not MpKit.is_networked() or not MpKit.is_server():
		return
	var slot := MpKit.slot_for_peer(from_peer)
	if slot <= 0:
		return
	_apply(RtsOrder.from_array(data.get("order"), self, _node_of), slot)


func _apply(order: RtsOrder, slot: int) -> void:
	if order == null:
		return
	orders.apply(order, slot)
	if DebugLog.on(&"orders"):
		print("order %s %d" % [order.command, order.units.size()])


func _id_of(body: Node) -> String:
	if units_root != null and body.get_parent() == units_root:
		return UNIT_ID + String(body.name)
	return PATH_ID + str(body.get_path())


func _node_of(id: String) -> Node:
	if id.begins_with(UNIT_ID):
		return units_root.get_node_or_null(NodePath(id.substr(UNIT_ID.length())))
	if id.begins_with(PATH_ID):
		return get_tree().root.get_node_or_null(NodePath(id.substr(PATH_ID.length())))
	return null


## The wizard of `slot`, where a retreat goes (the last one in the tree, as before).
func _wizard_of(slot: int) -> Node:
	var wizard: Node = null
	for node in get_tree().get_nodes_in_group(WizardBody.GROUP):
		if int(node.get("owner_slot")) == slot:
			wizard = node
	return wizard


## The enemy creature nearest `point` within `reach`, for an attack on a creature.
func _closest_enemy_creature(unit: RtsUnit, point: Vector3, reach: float) -> Node:
	var body := unit.body as UnitBody
	if body == null:
		return null
	var best: Node = null
	var best_d := reach
	for node in get_tree().get_nodes_in_group(UnitBody.GROUP):
		if not body.engagement.is_foe(node):
			continue
		var d := point.distance_to((node as Node3D).global_position)
		if d <= best_d:
			best_d = d
			best = node
	return best
