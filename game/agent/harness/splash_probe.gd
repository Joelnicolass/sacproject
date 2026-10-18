extends Node

## Observation only (RFC-028b playtest): `watch()` keeps where the next spell leaves %Spells (a Wrath bursts
## and frees itself in the same frame, so that is the burst point); `check` compares a building's splash
## with amount·(1 − d/r), d measured here, independently of SplashDamage: from the burst to the model box
## in data/catalog/body_sizes/ (single-piece BLDG at the building's origin, unturned). Moves no actor,
## edits no rule.


var center := Vector3.INF
var _spells: Node


## Hooks %Spells once (call before the cast).
func watch() -> String:
	if _spells != null and is_instance_valid(_spells):
		return "ya mirando"
	var root := get_tree().current_scene
	_spells = root.find_child("Spells", true, false) if root else null
	if _spells == null:
		return "sin Spells"
	_spells.child_exiting_tree.connect(func(node: Node) -> void:
		if node is Node3D:
			center = (node as Node3D).global_transform.origin)
	return "mirando %s" % _spells.get_path()


## "d=… esperado=… real=… ok|FALLA" for the building named `building_name` (rock_hit names it).
func check(building_name: String, amount: float, radius: float) -> String:
	var root := get_tree().current_scene
	var body := root.find_child(building_name, true, false) as Node3D if root else null
	if body == null or center == Vector3.INF:
		return "sin edificio o sin estallido"
	var tag := str(body.get("tag"))
	var record: Dictionary = MapBuilding.bldg(tag)
	var parts: Array = record.get("components", [])
	if parts.size() != 1 or float(parts[0].get("facing", 0.0)) != 0.0 or float(parts[0].get("x", 0.0)) != 0.0 or float(parts[0].get("y", 0.0)) != 0.0:
		return "%s: solo edificios de una pieza sin giro ni desplazamiento" % tag
	var raw: Array = BodyCatalog.measured(str(parts[0].get("tag", tag))).get("box", [])
	if raw.size() != 6:
		return "%s: sin caja horneada" % tag
	var low := Vector3(raw[0], raw[1], raw[2])
	var high := low + Vector3(raw[3], raw[4], raw[5])
	var local := body.global_transform.affine_inverse() * center
	var gap := Vector3(maxf(maxf(low.x - local.x, local.x - high.x), 0.0), maxf(maxf(low.y - local.y, local.y - high.y), 0.0), maxf(maxf(low.z - local.z, local.z - high.z), 0.0))
	var d := gap.length()
	var health := body.get_node("Health")
	var want := minf(amount * maxf(0.0, 1.0 - d / radius), float(health.get("maximum"))) if d <= radius else 0.0
	var got := float(health.get("maximum")) - float(health.get("current"))
	return "centro=%s d=%.3f esperado=%.1f real=%.1f %s" % [center, d, want, got, "ok" if absf(want - got) <= 1.0 else "FALLA"]
