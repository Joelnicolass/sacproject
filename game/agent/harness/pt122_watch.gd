extends Node

## Read-only observer for the F122 playtest (RFC-030 030k-a: Necryl cena, Deadeye lfda, Hellmouth mhba). It never moves,
## orders, doses or spawns anything; it reads the Druids' Health and Poisoning, counts the shots in flight, and re-frames
## the screen camera (like a player scrolling the view; the bench camera is fixed).
##
##   frame(x, z, ox, oy, oz)   screen camera at ground(x, z) + offset, looking at ground(x, z).
##   report()                  one line per Druid and per shooter.
## Props: tick, shots, d1..d5_hp, d1..d5_pois (0/1), d1..d5_dead (0/1), d1_pois_tick, d2_pois_tick, d1_dead_tick.

const NAMES := ["Druid1", "Druid2", "Druid3", "Druid4", "Druid5"]
const SHOOTERS := ["Necryl1", "Deadeye1", "Hellmouth1"]

var tick := 0
var shots := 0
var d1_hp := 0.0
var d2_hp := 0.0
var d3_hp := 0.0
var d4_hp := 0.0
var d5_hp := 0.0
var d1_pois := 0
var d2_pois := 0
var d3_pois := 0
var d4_pois := 0
var d5_pois := 0
var d1_dead := 0
var d2_dead := 0
var d1_pois_tick := -1
var d2_pois_tick := -1
var d3_pois_tick := -1
var d1_dead_tick := -1

var _bodies: Dictionary = {}  # name -> Node3D


func _ready() -> void:
	process_priority = 1000


func _find(n: String) -> Node3D:
	if _bodies.has(n) and is_instance_valid(_bodies[n]):
		return _bodies[n] as Node3D
	var found := get_tree().root.find_child(n, true, false) as Node3D
	if found:
		_bodies[n] = found
	return found


func _hp(n: String) -> float:
	var b := _find(n)
	if b == null:
		return -1.0
	var h := b.get_node_or_null("Health") as Health
	return h.current if h else -1.0


func _pois(n: String) -> int:
	var b := _find(n)
	if b == null:
		return 0
	var p := Poisoning.of(b)
	return 1 if p != null and p.is_poisoned() else 0


func _dead(n: String) -> int:
	var b := _find(n)
	if b == null:
		return 0
	var h := b.get_node_or_null("Health") as Health
	return 1 if h != null and h.is_dead() else 0


func _count_shots() -> int:
	var n := 0
	for sp in get_tree().get_nodes_in_group("shot_spawner"):
		var spawner := sp as MultiplayerSpawner
		if spawner == null or spawner.spawn_path.is_empty():
			continue
		var parent := spawner.get_node_or_null(spawner.spawn_path)
		if parent == null:
			continue
		for c in parent.get_children():
			if str(c.name).begins_with("Shot"):
				n += 1
	return n


func _physics_process(_delta: float) -> void:
	tick = MatchClock.now()
	shots = _count_shots()
	d1_hp = _hp("Druid1")
	d2_hp = _hp("Druid2")
	d3_hp = _hp("Druid3")
	d4_hp = _hp("Druid4")
	d5_hp = _hp("Druid5")
	d1_pois = _pois("Druid1")
	d2_pois = _pois("Druid2")
	d3_pois = _pois("Druid3")
	d4_pois = _pois("Druid4")
	d5_pois = _pois("Druid5")
	d1_dead = _dead("Druid1")
	d2_dead = _dead("Druid2")
	if d1_pois == 1 and d1_pois_tick < 0:
		d1_pois_tick = tick
	if d2_pois == 1 and d2_pois_tick < 0:
		d2_pois_tick = tick
	if d3_pois == 1 and d3_pois_tick < 0:
		d3_pois_tick = tick
	if d1_dead == 1 and d1_dead_tick < 0:
		d1_dead_tick = tick


func report() -> String:
	for n in NAMES + SHOOTERS:
		var b := _find(n)
		if b == null:
			print("PT122 %s no está" % n)
			continue
		var at := b.global_transform.origin
		var p := Poisoning.of(b)
		print("PT122 %s en (%.1f,%.1f,%.1f) vida %.1f envenenado %d muerto %d %s" % [n, at.x, at.y, at.z, _hp(n), _pois(n),
				_dead(n), ("dosis %d resist+%.2f regen×%.2f maná_bloq %s" % [p.get_child_count(), p.resistance_bonus(),
				p.regeneration_factor(), p.mana_blocked()]) if p else "sin Poisoning"])
	return "tick %d shots %d d1 %.1f/%d d2 %.1f/%d d3 %.1f/%d d4 %.1f/%d d5 %.1f/%d d1_pois@%d d2_pois@%d d3_pois@%d d1_dead@%d" % [
		tick, shots, d1_hp, d1_pois, d2_hp, d2_pois, d3_hp, d3_pois, d4_hp, d4_pois, d5_hp, d5_pois, d1_pois_tick,
		d2_pois_tick, d3_pois_tick, d1_dead_tick]


func frame(x: float, z: float, ox: float, oy: float, oz: float) -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return "no camera"
	var t := GroundSurface.of(self)
	var y := 0.0
	if t != null:
		var g: float = t.height_at(x, z)
		y = 0.0 if is_nan(g) else g
	var look := Vector3(x, y + 1.0, z)
	cam.look_at_from_position(look + Vector3(ox, oy, oz), look, Vector3.UP)
	return "framed (%.0f, %.0f) y %.1f" % [x, z, y]
