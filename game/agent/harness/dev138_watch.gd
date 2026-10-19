extends Node

## Read-only observer for the F138 developer check (RFC-030 030i-c, wizards stunned and petrified) on
## res://debug/units/f138_wizard_cc.tscn. It never moves, orders, damages or spawns anything. Tolerates a null scene.
##   arm()     connects to the wizards present (group "wizard").
##   report()  per wizard: every held episode (bits, frames, drift, yaw change, casting ticks, stone overrides, frozen
##             clip, tilt), the damage factor and the hurts taken while stone, and the first cast after each episode.

const STUNNED_BIT := 1
const PETRIFIED_BIT := 2

var _info: Dictionary = {}
var _armed := false


func _ready() -> void:
	process_physics_priority = 1000


func arm() -> String:
	if get_tree().current_scene == null:
		return "armed 0 (no scene)"
	for node in get_tree().get_nodes_in_group("wizard"):
		var body := node as Node3D
		if body == null or _info.has(body) or body.get_node_or_null("Afflictions") == null:
			continue
		var dyn: Variant = body
		_info[body] = {"name": str(dyn.display_name()), "slot": int(body.get("owner_slot")), "episodes": [], "cur": {},
			"stone_hurts": [], "free_casting": 0, "after": -1}
		body.get_node("Health").connect("hurt", _on_hurt.bind(body))
	_armed = true
	return "armed %d" % _info.size()


func _shown(body: Node3D) -> int:
	return int(body.get_node("Afflictions").get("shown"))


func _on_hurt(amount: float, kind: StringName, _from: int, body: Node3D) -> void:
	if _shown(body) & PETRIFIED_BIT:
		(_info[body]["stone_hurts"] as Array).append("%s %.2f f=%.2f" % [kind, amount,
			float(body.get_node("Afflictions").damage_factor())])


func _physics_process(_delta: float) -> void:
	if not _armed or get_tree().current_scene == null:
		return
	var now := Engine.get_physics_frames()
	for body: Node3D in _info:
		if not is_instance_valid(body):
			continue
		var i: Dictionary = _info[body]
		var bits := _shown(body)
		var cur: Dictionary = i["cur"]
		var origin := body.global_transform.origin
		var caster: Variant = body.get_node("Caster")
		var casting := bool(caster.is_casting())
		var mesh := body.get_node("Tilt/Mesh") as MeshInstance3D
		var tilt := body.get_node("Tilt") as Node3D
		var clip: Variant = body.get_node("ClipPose")
		if bits != 0 and cur.is_empty():
			cur = {"start": now, "bits": bits, "at": origin, "yaw": body.rotation.y, "drift": 0.0, "turn": 0.0,
				"casting": 0, "stone": 0, "frozen": 0, "tilt": 0.0, "frames": 0, "dmgf": 1.0}
			i["cur"] = cur
		if bits != 0:
			cur["bits"] = int(cur["bits"]) | bits
			cur["drift"] = maxf(float(cur["drift"]), Vector2(origin.x - cur["at"].x, origin.z - cur["at"].z).length())
			cur["turn"] = maxf(float(cur["turn"]), absf(angle_difference(float(cur["yaw"]), body.rotation.y)))
			cur["frames"] = int(cur["frames"]) + 1
			if casting:
				cur["casting"] = int(cur["casting"]) + 1
			if mesh.get_surface_override_material_count() > 0 and mesh.get_surface_override_material(0) is ShaderMaterial:
				cur["stone"] = int(cur["stone"]) + 1
			if bool(clip.get("frozen")):
				cur["frozen"] = int(cur["frozen"]) + 1
			cur["tilt"] = maxf(float(cur["tilt"]), rad_to_deg(absf(tilt.rotation.z)))
			if bits & PETRIFIED_BIT:
				cur["dmgf"] = float(body.get_node("Afflictions").damage_factor())
		elif not cur.is_empty():
			cur["end"] = now
			cur["back"] = -1
			(i["episodes"] as Array).append(cur)
			i["cur"] = {}
		if bits == 0 and casting and not (i["episodes"] as Array).is_empty():
			var last: Dictionary = (i["episodes"] as Array).back()
			if int(last["back"]) < 0:
				last["back"] = now


func report() -> String:
	for body: Node3D in _info:
		var i: Dictionary = _info[body]
		var eps := []
		for ep: Dictionary in i["episodes"]:
			eps.append("[pf %d..%d=%d bits %d drift %.4f turn %.4f casting %d stone %d frozen %d tilt %.1f dmgf %.2f cast_after %d]" % [
				ep["start"], ep["end"], int(ep["end"]) - int(ep["start"]), ep["bits"], ep["drift"], ep["turn"], ep["casting"],
				ep["stone"], ep["frozen"], ep["tilt"], ep["dmgf"], int(ep["back"]) - int(ep["end"]) if int(ep["back"]) >= 0 else -1])
		print("DEV138 %s slot=%d eps=%s stone_hurts=%s" % [i["name"], i["slot"], " ".join(eps), str(i["stone_hurts"])])
	return "DEV138 REPORT %d" % _info.size()
