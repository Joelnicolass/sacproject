extends Node

## Read-only observer for the F135 playtest (RFC-030 030e2b): the Collision capsule height of every hybrid flier
## against BodyCatalog.info(model) (height on the ground, height_flying while FLYING). It never moves, orders or
## spawns anything. The only thing it adds is an optional translucent overlay mesh under each Collision node
## (overlay(true)), so the capsule can be seen in a shot; it does not touch the shape.
##
##   arm(slot)      tracks units with a Flight child: slot -1 = local player, -2 = every slot. On the first tick a
##                  unit is seen it prints "PT135 first <name> <model> <STATE> cap=<h> want=<h>".
##   heights()      one line per tracked unit (state, capsule height, expected ground / flying height).
##   overlay(on)    overlay capsules on/off.
## Props for wait_until: tracked, first_flying, fly_ticks, fly_bad_ticks, ground_bad_ticks.

const _NAMES := ["GROUND", "TAKEOFF", "FLYING", "LANDING"]

var tracked := 0
var first_flying := 0
var fly_ticks := 0
var fly_bad_ticks := 0
var ground_bad_ticks := 0

var _on := false
var _slot := -1
var _units: Array[Node3D] = []
var _seen_bad: Dictionary = {}
var _show := false
var _overlay: Dictionary = {}
var _mat: StandardMaterial3D


func _ready() -> void:
	process_priority = 1000


func _local_slot() -> int:
	return MpKit.local_slot()


func _cap(u: Node3D) -> float:
	var col := u.get_node_or_null("Collision") as CollisionShape3D
	var capsule := col.shape as CapsuleShape3D if col else null
	return capsule.height if capsule else NAN


func _want(u: Node3D, state: int) -> float:
	var info := BodyCatalog.info(str(u.get("model")))
	var h := float(info.get("height", 1.8))
	if state == 2:
		h = float(info.get("height_flying", h))
	return maxf(h, 0.6)


func _state(u: Node3D) -> int:
	var f := u.get_node_or_null("Flight")
	return int(f.get("state")) if f else -1


func _line(u: Node3D) -> String:
	var st := _state(u)
	var info := BodyCatalog.info(str(u.get("model")))
	return "%s model=%s %s cap=%.2f want=%.2f (tierra %.2f vuelo %.2f)" % [u.name, str(u.get("model")), _NAMES[st] if st >= 0 else "?",
		_cap(u), _want(u, st), float(info.get("height", 0.0)), float(info.get("height_flying", 0.0))]


func arm(slot: int = -1) -> String:
	_slot = slot
	_on = true
	_units.clear()
	_scan()
	return "armed %d: %d" % [slot, tracked]


func _scan() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var slot := _slot if _slot >= 0 else _local_slot()
	for node in tree.get_nodes_in_group("unit"):
		if not node is Node3D or _units.has(node) or not (node as Node).has_node("Flight"):
			continue
		if _slot != -2 and int(node.get("owner_slot")) != slot:
			continue
		var u := node as Node3D
		_units.append(u)
		var st := _state(u)
		if st == 2:
			first_flying += 1
		print("PT135 first ", _line(u))
	tracked = _units.size()


func heights() -> String:
	for u in _units:
		if is_instance_valid(u):
			print("PT135 h ", _line(u))
	return "tracked %d first_flying %d fly_ticks %d fly_bad %d ground_bad %d" % [tracked, first_flying, fly_ticks, fly_bad_ticks, ground_bad_ticks]


func overlay(on: bool) -> String:
	_show = on
	if not on:
		for m in _overlay.values():
			if is_instance_valid(m):
				(m as Node).queue_free()
		_overlay.clear()
	return "show %s" % on


func _physics_process(_delta: float) -> void:
	if not _on:
		return
	_scan()
	for u in _units:
		if not is_instance_valid(u):
			continue
		var st := _state(u)
		var cap := _cap(u)
		if st == 2:
			fly_ticks += 1
			if absf(cap - _want(u, 2)) > 0.01:
				fly_bad_ticks += 1
				_report_bad(u, "fly")
		elif st == 0:
			if absf(cap - _want(u, 0)) > 0.01:
				ground_bad_ticks += 1
				_report_bad(u, "ground")


func _report_bad(u: Node3D, kind: String) -> void:
	var key := "%s:%s" % [u.get_instance_id(), kind]
	if _seen_bad.has(key):
		return
	_seen_bad[key] = true
	print("PT135 BAD %s %s" % [kind, _line(u)])


func _process(_delta: float) -> void:
	if not _show:
		return
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.albedo_color = Color(0.2, 1.0, 1.0, 0.35)
		_mat.no_depth_test = true
	for u in _units:
		if not is_instance_valid(u):
			continue
		var col := u.get_node_or_null("Collision") as CollisionShape3D
		var capsule := col.shape as CapsuleShape3D if col else null
		if capsule == null:
			continue
		var m: MeshInstance3D = _overlay.get(u)
		if m == null or not is_instance_valid(m):
			m = MeshInstance3D.new()
			m.mesh = CapsuleMesh.new()
			m.material_override = _mat
			col.add_child(m)
			_overlay[u] = m
		var mesh := m.mesh as CapsuleMesh
		mesh.height = capsule.height
		mesh.radius = minf(capsule.radius, capsule.height * 0.5)
