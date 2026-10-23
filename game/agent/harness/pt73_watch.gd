extends Node

## Observation only (024b2 playtest): after the world camera has placed itself each frame, re-frames it on a spot,
## a body, a pair of bodies or the first soul, and aims the camera's pointer at a body so the next order_units goes to
## it. report() prints what the villagers do. Moves no actor.
##   view("point:1262,1230", 70, 45, 0)   view("node:Farmer15", 12, 5, 30)   view("pair:Hunter,Farmer15", 20, 8, 0)   view("soul", 9, 3.5, 200)

var spec := ""
var dist := 14.0
var height := 3.0
var yaw_deg := 0.0


func _ready() -> void:
	process_priority = 1000


func view(new_spec: String, d: float = 14.0, h: float = 3.0, yaw: float = 0.0) -> void:
	spec = new_spec
	dist = d
	height = h
	yaw_deg = yaw


func _root() -> Node:
	return get_tree().current_scene


func _find(node_name: String) -> Node3D:
	var root := _root()
	return root.find_child(node_name, true, false) as Node3D if root else null


func _center() -> Variant:
	if spec.begins_with("point:"):
		var bits := spec.substr(6).split(",")
		var terrain: Variant = TerrainShape.of(self)
		var x := bits[0].to_float()
		var z := bits[1].to_float()
		var y: float = terrain.height_at(x, z) if terrain else 0.0
		return Vector3(x, 0.0 if is_nan(y) else y, z)
	if spec.begins_with("node:"):
		var node := _find(spec.substr(5))
		return node.global_transform.origin + Vector3(0, 1.2, 0) if node else null
	if spec.begins_with("pair:"):
		var names := spec.substr(5).split(",")
		var a := _find(names[0])
		var b := _find(names[1])
		return (a.global_transform.origin + b.global_transform.origin) * 0.5 + Vector3(0, 1.5, 0) if a and b else null
	if spec == "soul":
		for soul in get_tree().get_nodes_in_group("soul"):
			if soul is Node3D and not (soul as Node).is_queued_for_deletion():
				return (soul as Node3D).global_transform.origin + Vector3(0, 1.4, 0)
	return null


var _marks := {}
var _last_count := -1
var _gain_ms := {}


## Wall-clock label for since_gain().
func mark(label: String) -> String:
	_marks[label] = Time.get_ticks_msec()
	_gain_ms.erase(label)
	return "marca %s" % label


## Seconds from mark(label) to the first time the wizard's soul count went up; -1 if it has not.
func since_gain(label: String) -> String:
	if not _gain_ms.has(label):
		return "%s: sin ganancia todavia (%.1f s desde la marca)" % [label, float(Time.get_ticks_msec() - int(_marks.get(label, 0))) / 1000.0]
	return "%s: almas +1 a los %.1f s de la marca" % [label, float(int(_gain_ms[label]) - int(_marks.get(label, 0))) / 1000.0]


func _track_souls() -> void:
	var wizard := get_tree().get_first_node_in_group("local_wizard")
	var purse := wizard.get_node_or_null("SoulPurse") if wizard else null
	if purse == null:
		return
	var count := int(purse.get("count"))
	if _last_count >= 0 and count > _last_count:
		for label in _marks:
			if not _gain_ms.has(label):
				_gain_ms[label] = Time.get_ticks_msec()
	_last_count = count


func _process(_delta: float) -> void:
	_track_souls()
	if spec.is_empty():
		return
	var root := _root()
	var cam := root.get_node_or_null("HighNoon/Camera") as Camera3D if root else null
	var center: Variant = _center()
	if cam == null or center == null:
		return
	var dir := Vector3(sin(deg_to_rad(yaw_deg)), 0, cos(deg_to_rad(yaw_deg)))
	cam.position = (center as Vector3) + dir * dist + Vector3(0, height, 0)
	cam.look_at(center as Vector3, Vector3.UP)


## The pointer of the world camera on a body (what the next order_units points at).
func aim(node_name: String) -> String:
	var node := _find(node_name)
	var cam := _root().get_node_or_null("HighNoon/Camera") as Camera3D
	if node == null or cam == null:
		return "sin %s" % node_name
	var spot := cam.unproject_position(node.global_transform.origin + Vector3(0, 1.0, 0))
	cam.set("debug_pointer", spot)
	return "pointer (%d, %d) en %s" % [spot.x, spot.y, node_name]


func report() -> String:
	var out := "t=%.1f " % (Time.get_ticks_msec() / 1000.0)
	var hunter := _find("Hunter")
	if hunter != null:
		var target: Variant = hunter.get("target")
		out += "Hunter[(%.0f,%.0f) mode=%s tgt=%s] " % [hunter.global_transform.origin.x, hunter.global_transform.origin.z, hunter.get("mode"), (target as Node).name if target else "-"]
	var modes := {}
	for npc in get_tree().get_nodes_in_group("npc"):
		var key := str(UnitBody.Mode.keys()[int(npc.get("mode"))])
		modes[key] = int(modes.get(key, 0)) + 1
	out += "npc%s " % str(modes)
	for soul in get_tree().get_nodes_in_group("soul"):
		out += "soul[%s n=%s slot=%s state=%s attached=%s] " % [soul.name, soul.get("number"), soul.get("owner_slot"), soul.get("state"), soul.get("attached")]
	var wizard := get_tree().get_first_node_in_group("local_wizard") as Node3D
	if wizard != null:
		var purse := wizard.get_node_or_null("SoulPurse")
		out += "mago(%.0f,%.0f) almas=%s" % [wizard.global_transform.origin.x, wizard.global_transform.origin.z, purse.get("count") if purse else "-"]
	return out


func farmer(node_name: String) -> String:
	var body := _find(node_name)
	if body == null:
		return "sin %s" % node_name
	var behavior := body.get_node_or_null("PeasantBehavior")
	return "%s (%.1f,%.1f) mode=%s estado=%s hp=%s" % [node_name, body.global_transform.origin.x, body.global_transform.origin.z,
		UnitBody.Mode.keys()[int(body.get("mode"))], behavior.get("state") if behavior else "-", body.get_node("Health").get("current")]


## Nothing selected: the next order_units walks the wizard (what a click on empty ground does without a selection).
func deselect() -> String:
	var selection := _root().find_child("Selection", true, false)
	if selection == null:
		return "sin Selection"
	selection.clear()
	return "seleccion vacia"


## The pointer on the ground `back_m` meters from the first soul, on the wizard's side of it.
func aim_ground_near_soul(back_m: float) -> String:
	var cam := _root().get_node_or_null("HighNoon/Camera") as Camera3D
	var wizard := get_tree().get_first_node_in_group("local_wizard") as Node3D
	var soul: Node3D = null
	for node in get_tree().get_nodes_in_group("soul"):
		if node is Node3D:
			soul = node as Node3D
			break
	if cam == null or wizard == null or soul == null:
		return "falta camara, mago o alma"
	var to_wizard := wizard.global_transform.origin - soul.global_transform.origin
	to_wizard.y = 0.0
	var spot := soul.global_transform.origin + to_wizard.normalized() * back_m
	var terrain: Variant = TerrainShape.of(self)
	var y: float = terrain.height_at(spot.x, spot.z)
	spot.y = 0.0 if is_nan(y) else y
	var screen := cam.unproject_position(spot)
	cam.set("debug_pointer", screen)
	return "pointer (%d, %d) a %.0f m del alma, mago a %.0f m" % [screen.x, screen.y, back_m, to_wizard.length()]


func soul_distance() -> String:
	var wizard := get_tree().get_first_node_in_group("local_wizard") as Node3D
	for node in get_tree().get_nodes_in_group("soul"):
		if node is Node3D and wizard != null:
			var d := (node as Node3D).global_transform.origin - wizard.global_transform.origin
			return "mago a %.1f m del alma %s" % [Vector2(d.x, d.z).length(), node.name]
	return "sin alma"


## Why a creature does not strike: reach, facing and distance to its target.
func melee_probe(attacker_name: String, target_name: String) -> String:
	var attacker := _find(attacker_name)
	var target := _find(target_name)
	if attacker == null or target == null:
		return "falta %s o %s" % [attacker_name, target_name]
	var melee: Variant = attacker.get_node("MeleeAttack")
	var d := target.global_transform.origin - attacker.global_transform.origin
	var flat := Vector2(d.x, d.z)
	var facing: Vector3 = attacker.facing_flat()
	return "dist=%.2f dy=%.2f can_start=%s in_reach1=%s reach=%.2f foe=%s facing_dot=%.2f speed=%s ordered=%s" % [
		flat.length(), d.y, melee.can_start(target), melee.in_reach(target, 1.0), melee.reach, str(melee.profile_of(target)),
		facing.dot(Vector3(d.x, 0, d.z).normalized()), attacker.get("move_speed"), attacker.get("ordered")]


## Taurock1 against Hunter: distance, modes, target and the health of both.
func taurock() -> String:
	var taurock_body := _find("Taurock1")
	var hunter := _find("Hunter")
	if taurock_body == null or hunter == null:
		return "falta Taurock1 o Hunter"
	var target: Variant = taurock_body.get("target")
	var d := taurock_body.global_transform.origin - hunter.global_transform.origin
	return "Taurock dist=%.1f modo=%s blanco=%s vida=%s | Hunter modo=%s vida=%s" % [Vector2(d.x, d.z).length(),
		UnitBody.Mode.keys()[int(taurock_body.get("mode"))], (target as Node).name if target else "-",
		taurock_body.get_node("Health").get("current"), UnitBody.Mode.keys()[int(hunter.get("mode"))], hunter.get_node("Health").get("current")]
