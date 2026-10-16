extends Node

## Observation only: re-frames the world camera on the enemy altar / mago 2 / the creature / a doctor,
## and reports ritual state as a string. Touches no actor.

var target := ""
var dist := 40.0
var height := 20.0
var yaw_deg := 0.0
var look_y := 8.0
var t0 := 0


func _ready() -> void:
	process_priority = 1000
	t0 = Time.get_ticks_msec()


func clock() -> String:
	return "%.1f" % ((Time.get_ticks_msec() - t0) / 1000.0)


func set_view(t: String, d: float, h: float, yaw: float, ly: float) -> void:
	target = t
	dist = d
	height = h
	yaw_deg = yaw
	look_y = ly


func _find(n: String) -> Node3D:
	var root := get_tree().current_scene
	return root.find_child(n, true, false) as Node3D if root else null


func _center() -> Variant:
	var n: Node3D = null
	match target:
		"altar":
			var s := _find("Start2")
			n = s.get_node_or_null("Altar") as Node3D if s else null
		"wizard2":
			n = _find("Wizard2")
		"creature":
			n = _find("Offering")
		"doctor1":
			n = _find("Doctor1")
		"doctor2":
			n = _find("Doctor2")
	if n == null:
		return null
	return n.global_transform.origin + Vector3(0, look_y, 0)


func _process(_d: float) -> void:
	if target == "":
		return
	var root := get_tree().current_scene
	var cam := root.get_node_or_null("HighNoon/Camera") as Camera3D if root else null
	var c: Variant = _center()
	if cam == null or c == null:
		return
	var dir := Vector3(sin(deg_to_rad(yaw_deg)), 0, cos(deg_to_rad(yaw_deg)))
	cam.position = (c as Vector3) + dir * dist + Vector3(0, height, 0)
	cam.look_at(c as Vector3, Vector3.UP)


func _txt(n: String) -> String:
	var root := get_tree().current_scene
	var x := root.find_child(n, true, false) if root else null
	if x == null:
		return "-"
	var v := ""
	if x.get("text") != null:
		v = str(x.get("text")).replace("\n", " ")
	var vis := false
	if x is CanvasItem:
		vis = (x as CanvasItem).is_visible_in_tree()
	return "%s[%s]" % [v, "V" if vis else "h"]


func snap() -> String:
	var root := get_tree().current_scene
	var r := root.find_child("Ritual1", true, false) if root else null
	var ph := "-"
	var rd := "-"
	var oc := "-"
	if r:
		ph = str(r.get("phase"))
		rd = str(r.get("round_index"))
		oc = str(r.get("outcome"))
	var w := root.find_child("Wizard2", true, false) if root else null
	var hp := "-"
	if w and w.get_node_or_null("Health"):
		hp = str(w.get_node("Health").get("current"))
	var s := _find("Start2")
	var al := s.get_node_or_null("Altar") if s else null
	var ast := str(al.get("state")) if al else "-"
	var docs := (root.find_child("SacrificeSystem", true, false).get_node_or_null("Doctors") if root and root.find_child("SacrificeSystem", true, false) else null)
	var nd := str(docs.get_child_count()) if docs else "-"
	var off := _find("Offering")
	var mode := str(off.get("mode")) if off else "gone"
	var wp := ""
	if w is Node3D:
		wp = str((w as Node3D).global_transform.origin)
	var ap := ""
	if al is Node3D:
		ap = str((al as Node3D).global_transform.origin)
	var cam := root.get_node_or_null("HighNoon/Camera") as Camera3D if root else null
	var cp := str(cam.global_transform.origin) if cam else "-"
	return "pos w2=%s altar=%s cam=%s " % [wp, ap, cp] + "t=%s phase=%s round=%s outcome=%s hp2=%s altar=%s doctors=%s off_mode=%s notice=%s result=%s" % [clock(), ph, rd, oc, hp, ast, nd, mode, _txt("RitualNotice"), _txt("MatchResult")]
