extends Node

## Read-only observer for the F137 developer check (RFC-030 030i-b, Basilisk petrify) on res://debug/units/f137_petrify.tscn.
## It never moves, orders, damages or spawns anything. Tolerates a null scene.
##   arm()     connects to the units present (group "unit").
##   report()  per unit: petrified episodes (frames, drift, clip frame changes, stone overrides, min height over the
##             ground), hits taken while stone vs the struck amount (ratio), direct ranged hurts, struck after the stun,
##             and for a flier the height after it.

const PETRIFIED_BIT := 2
const STUNNED_BIT := 1

var done := false

var _info: Dictionary = {}
var _armed := false


func _ready() -> void:
	process_physics_priority = 1000


func _terrain() -> TerrainShape:
	if get_tree().current_scene == null:
		return null
	return TerrainShape.of(self)


func arm() -> String:
	if get_tree().current_scene == null:
		return "armed 0 (no scene)"
	for node in get_tree().get_nodes_in_group("unit"):
		var body := node as Node3D
		if body == null or _info.has(body) or body.get_node_or_null("Afflictions") == null:
			continue
		var dyn: Variant = body
		_info[body] = {"name": str(dyn.display_name()), "slot": int(body.get("owner_slot")), "episodes": [],
			"cur": {}, "pending": -1.0, "ratios": [], "ranged": 0, "stun_end": -1, "back": "", "after_h": -1.0,
			"after_frames": 0, "z": body.global_transform.origin.z}
		body.connect("struck", _on_struck.bind(body))
		var health := body.get_node("Health")
		health.connect("hit", _on_hit.bind(body))
		health.connect("hurt", _on_hurt.bind(body))
	_armed = true
	return "armed %d" % _info.size()


func _shown(body: Node3D) -> int:
	return int(body.get_node("Afflictions").get("shown"))


func _on_hit(amount: float, _from: int, _full: bool, body: Node3D) -> void:
	_info[body]["pending"] = amount


func _on_struck(target: Node3D, amount: float, _c: float, _r: float, body: Node3D) -> void:
	var i: Dictionary = _info[body]
	if int(i["stun_end"]) >= 0 and str(i["back"]).is_empty():
		i["back"] = "pf=%d" % Engine.get_physics_frames()
	if target == null or not _info.has(target):
		return
	var t: Dictionary = _info[target]
	if float(t["pending"]) >= 0.0 and amount > 0.0:
		(t["ratios"] as Array).append("%.1f/%.1f=%.3f%s" % [float(t["pending"]), amount, float(t["pending"]) / amount,
			"P" if _shown(target) & PETRIFIED_BIT else ""])
	t["pending"] = -1.0


func _on_hurt(amount: float, kind: StringName, _from: int, body: Node3D) -> void:
	if kind == &"direct_ranged" and _shown(body) & PETRIFIED_BIT:
		_info[body]["ranged"] = int(_info[body]["ranged"]) + 1
	if kind == &"direct_ranged":
		print("DEV137 RANGED %s %.1f pf=%d" % [_info[body]["name"], amount, Engine.get_physics_frames()])


func _above(body: Node3D) -> float:
	var t: Variant = _terrain()
	var o := body.global_transform.origin
	return o.y - float(t.height_at(o.x, o.z)) if t != null else NAN


func _ray_above(body: Node3D) -> float:
	var o := body.global_transform.origin
	var q := PhysicsRayQueryParameters3D.create(o + Vector3.UP * 50.0, o + Vector3.DOWN * 50.0)
	q.collision_mask = 1
	var hit := body.get_world_3d().direct_space_state.intersect_ray(q)
	return o.y - float(hit.position.y) if not hit.is_empty() else NAN


func _physics_process(_delta: float) -> void:
	if not _armed or get_tree().current_scene == null:
		return
	var now := Engine.get_physics_frames()
	for body: Node3D in _info:
		if not is_instance_valid(body):
			continue
		var i: Dictionary = _info[body]
		var stone := _shown(body) & PETRIFIED_BIT != 0
		var cur: Dictionary = i["cur"]
		var clip: Variant = body.get_node("ClipPose")
		var mesh := body.get_node("Tilt/Mesh") as MeshInstance3D
		var key := "%s/%d/%s" % [clip.active_role(), int(clip.active_frame()), str(mesh.mesh)]
		if stone and cur.is_empty():
			cur = {"start": now, "at": body.global_transform.origin, "drift": 0.0, "key": key, "changes": 0, "stone": 0,
				"min_h": _above(body), "min_ray": _ray_above(body), "frames": 0,
				"mode_before": i.get("last_mode", -1), "mode": int(body.get("mode")),
				"dmgf": float(body.get_node("Health").get("damage_factor"))}
			i["cur"] = cur
		elif stone:
			cur["drift"] = maxf(float(cur["drift"]), Vector2(body.global_transform.origin.x - cur["at"].x,
				body.global_transform.origin.z - cur["at"].z).length())
			if key != str(cur["key"]):
				cur["changes"] = int(cur["changes"]) + 1
				cur["key"] = key
			cur["frames"] = int(cur["frames"]) + 1
			if mesh.get_surface_override_material_count() > 0 and mesh.get_surface_override_material(0) is ShaderMaterial:
				cur["stone"] = int(cur["stone"]) + 1
			cur["min_h"] = minf(float(cur["min_h"]), _above(body))
			cur["min_ray"] = minf(float(cur["min_ray"]), _ray_above(body))
			var cb := body as CharacterBody3D
			var cap := (body.get_node("Collision") as CollisionShape3D).shape as CapsuleShape3D
			cur["floor"] = "on=%s n=%s r=%.2f h=%.2f" % [cb.is_on_floor(), str(cb.get_floor_normal()), cap.radius if cap else -1.0,
				cap.height if cap else -1.0]
		elif not cur.is_empty():
			cur["end"] = now
			(i["episodes"] as Array).append(cur)
			i["cur"] = {}
			i["after_frames"] = 0
			i["after_h"] = -1.0
		i["last_mode"] = int(body.get("mode"))
		if not stone and (i["episodes"] as Array).size() > 0 and int(i["after_frames"]) < 900:
			i["after_frames"] = int(i["after_frames"]) + 1
			i["after_h"] = maxf(float(i["after_h"]), _ray_above(body))
		if _shown(body) & STUNNED_BIT == 0 and (i["episodes"] as Array).size() > 0 and int(i["stun_end"]) < 0 \
				and now - int((i["episodes"] as Array)[0]["end"]) > 2:
			i["stun_end"] = now


func report() -> String:
	for body: Node3D in _info:
		var i: Dictionary = _info[body]
		var eps := []
		for ep: Dictionary in i["episodes"]:
			eps.append("[pf %d..%d=%d drift %.4f clip_changes %d stone %d/%d min_h %.3f min_ray %.3f]" % [ep["start"],
				ep["end"], int(ep["end"]) - int(ep["start"]), ep["drift"], ep["changes"], ep["stone"], ep["frames"], ep["min_h"],
				ep["min_ray"]])
			eps.append("%s mode %d->%d dmgf %.2f" % [str(ep.get("floor", "")), ep["mode_before"], ep["mode"], ep["dmgf"]])
		print("DEV137 %s slot=%d z=%.0f alive=%s eps=%s ratios=%s ranged_while_stone=%d stun_end=%d back=%s after_h=%.3f" % [
			i["name"], i["slot"], float(i["z"]) - 1270.0, is_instance_valid(body), " ".join(eps), str(i["ratios"]), i["ranged"],
			i["stun_end"], i["back"], i["after_h"]])
	return "DEV137 REPORT %d" % _info.size()


## Developer probe: the ground's slope (degrees) at candidate lanes around the anchor, by ray.
func slopes() -> String:
	if get_tree().current_scene == null:
		return "no scene"
	var space := (get_tree().get_nodes_in_group("unit")[0] as Node3D).get_world_3d().direct_space_state
	for dz in [-240, -200, -160, 0, 160, 200, 240]:
		var row := []
		for dx in range(-80, 100, 20):
			var at := Vector3(1270.0 + dx, 0.0, 1270.0 + dz)
			var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 500.0, at + Vector3.DOWN * 500.0)
			q.collision_mask = 1
			var hit := space.intersect_ray(q)
			row.append("--" if hit.is_empty() else "%d" % roundi(rad_to_deg((hit.normal as Vector3).angle_to(Vector3.UP))))
		print("DEV137 SLOPE z%+d: %s" % [dz, " ".join(row)])
	return "ok"


## Developer check (B2): petrifies the enemy Earthfling standing as a rock through the product's own entry point (what
## PetrifyImpact does when the gaze touches it), because no AI aims at a rock. 600 ticks, as the gaze on 960 of health.
func petrify_rock() -> String:
	if get_tree().current_scene == null:
		return "no scene"
	for body: Node3D in _info:
		if is_instance_valid(body) and str(_info[body]["name"]) == "Earthfling":
			var dyn: Variant = body
			var was_rock := bool(dyn.is_rock_form())
			var stone: Variant = body.get_node("Afflictions/Petrified")
			var ok := bool(stone.petrify(600))
			var r := "DEV137 ROCK was_rock=%s petrified=%s rock_now=%s dmgf=%.2f aff=%.2f" % [was_rock, ok, bool(dyn.is_rock_form()),
				float(body.get_node("Health").get("damage_factor")), float(body.get_node("Afflictions").damage_factor())]
			print(r)
			return r
	return "no Earthfling"
