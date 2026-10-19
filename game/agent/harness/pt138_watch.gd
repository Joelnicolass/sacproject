extends Node

## Read-only observer for the F138 playtest (RFC-030 030i-c) on res://debug/units/f138_wizard_cc.tscn. Never moves, orders,
## damages or spawns anything. Tolerates a null scene. Watches the wizard of slot 2 (Marduk) only.
##   arm()     finds the wizard.
##   phase     "" | "stun1" | "stone" | "stun2" | "back" for the flow's shots (back = acted after the last hold).
##   report()  every segment of Afflictions.shown (bits, frames, drift, turn, casting ticks, stone material ticks, tilt,
##             damage factor), hurts and hits with the factor and the bits at that moment, the first cast and walk after
##             the last hold, and Tilt.position.y after a death. Live lines are printed as PT138 too.

const STUNNED_BIT := 1
const PETRIFIED_BIT := 2

var phase := ""
var done := false
var _body: Node3D
var _armed := false
var _segs: Array = []
var _cur: Dictionary = {}
var _hurts: Array = []
var _saw_stone := false
var _last_end := -1
var _after_at := Vector3.ZERO
var _cast_after := -1
var _walk_after := -1
var _death := {}


func _ready() -> void:
	process_physics_priority = 1000


func arm() -> String:
	if get_tree().current_scene == null:
		return "armed 0 (no scene)"
	for node in get_tree().get_nodes_in_group("wizard"):
		var body := node as Node3D
		if body and int(body.get("owner_slot")) == 2 and body.get_node_or_null("Afflictions"):
			_body = body
	if _body == null:
		return "armed 0 (no slot 2 wizard)"
	var health := _body.get_node("Health")
	health.connect("hurt", _on_hurt)
	health.connect("hit", _on_hit)
	health.connect("died", _on_died)
	_armed = true
	var dyn: Variant = _body
	return "armed %s" % str(dyn.display_name())


func _bits() -> int:
	return int(_body.get_node("Afflictions").get("shown"))


func _factor() -> float:
	var aff: Variant = _body.get_node("Afflictions")
	return float(aff.damage_factor())


func _on_hurt(amount: float, kind: StringName, from_slot: int) -> void:
	var line := "hurt pf=%d kind=%s taken=%.3f from=%d bits=%d factor=%.2f" % [Engine.get_physics_frames(), kind, amount,
		from_slot, _bits(), _factor()]
	_hurts.append(line)
	print("PT138 ", line)


func _on_hit(amount: float, from_slot: int, _was_full: bool) -> void:
	var line := "hit pf=%d amount=%.3f from=%d bits=%d factor=%.2f" % [Engine.get_physics_frames(), amount, from_slot,
		_bits(), _factor()]
	_hurts.append(line)
	print("PT138 ", line)


func _on_died(from_slot: int) -> void:
	_death = {"pf": Engine.get_physics_frames(), "bits": _bits(), "from": from_slot, "tilt_y_max_after": 0.0, "samples": 0}
	print("PT138 died pf=%d bits=%d" % [_death["pf"], _death["bits"]])


func _physics_process(_delta: float) -> void:
	if not _armed or get_tree().current_scene == null or not is_instance_valid(_body):
		return
	var now := Engine.get_physics_frames()
	var bits := _bits()
	var origin := _body.global_transform.origin
	var caster: Variant = _body.get_node("Caster")
	var casting := bool(caster.is_casting())
	var tilt := _body.get_node("Tilt") as Node3D
	if _cur.is_empty() or int(_cur["bits"]) != bits:
		if not _cur.is_empty():
			_cur["end"] = now
			_segs.append(_cur)
			print("PT138 seg bits=%d pf %d..%d = %d drift=%.4f turn=%.4f casting=%d stone=%d tilt=%.1f" % [_cur["bits"],
				_cur["start"], now, now - int(_cur["start"]), _cur["drift"], _cur["turn"], _cur["casting"], _cur["stone"],
				_cur["tilt"]])
			if int(_cur["bits"]) != 0 and bits == 0:
				_last_end = now
				_after_at = origin
				_cast_after = -1
				_walk_after = -1
		_cur = {"start": now, "bits": bits, "at": origin, "yaw": _body.rotation.y, "drift": 0.0, "turn": 0.0,
			"casting": 0, "stone": 0, "tilt": 0.0, "dmgf": _factor()}
		if bits & PETRIFIED_BIT:
			_saw_stone = true
			phase = "stone"
		elif bits & STUNNED_BIT:
			phase = "stun2" if _saw_stone else "stun1"
	_cur["drift"] = maxf(float(_cur["drift"]), Vector2(origin.x - _cur["at"].x, origin.z - _cur["at"].z).length())
	_cur["turn"] = maxf(float(_cur["turn"]), absf(angle_difference(float(_cur["yaw"]), _body.rotation.y)))
	if casting:
		_cur["casting"] = int(_cur["casting"]) + 1
	var mesh := _body.get_node_or_null("Tilt/Mesh") as MeshInstance3D
	if mesh and mesh.get_surface_override_material_count() > 0 and mesh.get_surface_override_material(0) is ShaderMaterial:
		_cur["stone"] = int(_cur["stone"]) + 1
	_cur["tilt"] = maxf(float(_cur["tilt"]), rad_to_deg(absf(tilt.rotation.z)))
	if bits == 0 and _last_end >= 0:
		if casting and _cast_after < 0:
			_cast_after = now - _last_end
			print("PT138 cast_after %d" % _cast_after)
		if _walk_after < 0 and Vector2(origin.x - _after_at.x, origin.z - _after_at.z).length() > 0.3:
			_walk_after = now - _last_end
			print("PT138 walk_after %d" % _walk_after)
		if _saw_stone and (_cast_after >= 0 or _walk_after >= 0):
			phase = "back"
	if not _death.is_empty():
		_death["samples"] = int(_death["samples"]) + 1
		if int(_death["samples"]) > 30:
			_death["tilt_y_max_after"] = maxf(float(_death["tilt_y_max_after"]), absf(tilt.position.y))


func report() -> String:
	if not _armed:
		done = true
		return "PT138 REPORT not armed"
	for s: Dictionary in _segs:
		print("PT138 SEG bits=%d pf %d..%d = %d drift=%.4f turn=%.4f casting=%d stone=%d tilt=%.1f dmgf=%.2f" % [s["bits"],
			s["start"], s["end"], int(s["end"]) - int(s["start"]), s["drift"], s["turn"], s["casting"], s["stone"], s["tilt"],
			s["dmgf"]])
	print("PT138 HURTS %s" % str(_hurts))
	print("PT138 AFTER last_end=%d cast_after=%d walk_after=%d" % [_last_end, _cast_after, _walk_after])
	print("PT138 DEATH %s tilt_y_now=%.4f" % [str(_death), (_body.get_node("Tilt") as Node3D).position.y])
	done = true
	return "PT138 REPORT %d segs" % _segs.size()
