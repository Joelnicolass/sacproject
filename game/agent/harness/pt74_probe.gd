extends Node

## Observation only (RFC-024 024c playtest): prints every `period_s` the units of the field (slot, type, position, target, distance
## to the wizard of slot 2). Touches nothing. Off until start() is called from a flow step.

var period_s := 1.0
var _on := false
var _acc := 0.0


func start(period: float = 1.0) -> void:
	period_s = period
	_on = true


func stop() -> void:
	_on = false


func _process(delta: float) -> void:
	if not _on:
		return
	_acc += delta
	if _acc < period_s:
		return
	_acc = 0.0
	var tree := get_tree()
	var wiz: Node3D = null
	for w in tree.get_nodes_in_group("wizard"):
		if int(w.get("owner_slot")) == 2:
			wiz = w as Node3D
	var parts: PackedStringArray = []
	for node in tree.get_nodes_in_group("unit"):
		var u: Variant = node
		var body := node as Node3D
		if body == null or bool(u.is_dead()):
			continue
		var slot := int(u.get("owner_slot"))
		if slot != 1 and slot != 2:
			continue
		var type: Variant = u.get("type")
		var tname := str((type as CreatureType).display_name) if type != null else "?"
		var tgt: Variant = u.get("target")
		var tg := str((tgt as Node).name) if tgt is Node and is_instance_valid(tgt) else "-"
		var d := -1.0
		if wiz != null:
			d = Vector2(body.global_transform.origin.x - wiz.global_transform.origin.x, body.global_transform.origin.z - wiz.global_transform.origin.z).length()
		var tslot := -1
		if tgt is Node and is_instance_valid(tgt):
			tslot = int((tgt as Node).get("owner_slot"))
		var near_npc := 9999.0
		for other in tree.get_nodes_in_group("unit"):
			var o: Variant = other
			var ob := other as Node3D
			if ob == null or int(o.get("owner_slot")) < 3 or bool(o.is_dead()):
				continue
			near_npc = minf(near_npc, Vector2(body.global_transform.origin.x - ob.global_transform.origin.x, body.global_transform.origin.z - ob.global_transform.origin.z).length())
		parts.append("s%d %s d=%.0f tgt=%s(s%d) npc=%.0f" % [slot, tname, d, tg, tslot, near_npc])
	print("PT74 ", " | ".join(parts))
