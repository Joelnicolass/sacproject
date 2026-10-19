extends Node

## Read-only observer for the F123 window run (RFC-030 030l: Tickferno sfba, Pyromaniac lffa, Bombard cfba). It never
## moves, orders or ignites anything; it reads the targets' Health and their Burning children, counts the shots in flight
## and re-frames the screen camera (like a player scrolling the view; the bench camera is fixed).
##
##   frame(x, z, ox, oy, oz)   screen camera at ground(x, z) + offset, looking at ground(x, z).
##   report()                  one line per target.
## Props: tick, shots, <target>_fire (0/1) for Druid1 (lane A), Trogg1 (lane B), Druid2..4 (lane C).

const _TERRAIN := preload("res://scenes/map/terrain/terrain.gd")
const NAMES := ["Druid1", "Trogg1", "Druid2", "Druid3", "Druid4"]

var tick := 0
var shots := 0
var druid1_fire := 0
var trogg1_fire := 0
var druid2_fire := 0
var druid3_fire := 0
var druid4_fire := 0

var _bodies: Dictionary = {}
## Shots in flight: node -> [tag, first tick seen]; and the flights already over ("tag N ticks").
var _flying: Dictionary = {}
var _flights: PackedStringArray = []


func _ready() -> void:
	process_priority = 1000


func _find(n: String) -> Node3D:
	if _bodies.has(n) and is_instance_valid(_bodies[n]):
		return _bodies[n] as Node3D
	var found := get_tree().root.find_child(n, true, false) as Node3D
	if found:
		_bodies[n] = found
	return found


func _fires(n: String) -> int:
	var b := _find(n)
	if b == null:
		return 0
	var count := 0
	for c in b.get_children():
		if c is Burning:
			count += 1
	return count


func _hp(n: String) -> float:
	var b := _find(n)
	var h := b.get_node_or_null("Health") as Health if b else null
	return h.current if h else -1.0


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
	_track_flights()
	druid1_fire = mini(1, _fires("Druid1"))
	trogg1_fire = mini(1, _fires("Trogg1"))
	druid2_fire = mini(1, _fires("Druid2"))
	druid3_fire = mini(1, _fires("Druid3"))
	druid4_fire = mini(1, _fires("Druid4"))


## The flight time of each shot, from the tick it is first seen to the tick it is gone (it bursts and frees itself).
func _track_flights() -> void:
	var seen := {}
	for sp in get_tree().get_nodes_in_group("shot_spawner"):
		var spawner := sp as MultiplayerSpawner
		if spawner == null or spawner.spawn_path.is_empty():
			continue
		var parent := spawner.get_node_or_null(spawner.spawn_path)
		if parent == null:
			continue
		for c in parent.get_children():
			if not str(c.name).begins_with("Shot"):
				continue
			seen[c] = true
			if not _flying.has(c):
				var ability: Variant = c.get("ability")
				_flying[c] = [str(ability.get("tag")) if ability else "?", tick]
	for c in _flying.keys():
		if not seen.has(c):
			_flights.append("%s %d ticks (%d-%d)" % [_flying[c][0], tick - int(_flying[c][1]), int(_flying[c][1]), tick])
			_flying.erase(c)


## The body's box on screen (x0, y0, x1, y1), to measure the pixels a capture shows over it.
func _screen_box(n: String) -> String:
	var b := _find(n)
	var cam := get_viewport().get_camera_3d()
	if b == null or cam == null:
		return "-"
	var box := BodyNudge.box(b)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in 8:
		var corner := box.get_endpoint(i)
		if cam.is_position_behind(corner):
			return "-"
		var p := cam.unproject_position(corner)
		lo = lo.min(p)
		hi = hi.max(p)
	return "%d,%d,%d,%d" % [lo.x, lo.y, hi.x, hi.y]


func report() -> String:
	var parts: PackedStringArray = []
	for n in NAMES:
		var b := _find(n)
		var mana := b.get_node_or_null("ManaPool") as ManaPool if b else null
		parts.append("%s vida %.1f maná %.2f fuegos %d caja %s" % [n, _hp(n), mana.current if mana else -1.0, _fires(n), _screen_box(n)])
	var line := "PT123 tick %d shots %d · %s · vuelos: %s" % [tick, shots, " · ".join(parts), ", ".join(_flights)]
	print(line)
	return line


func frame(x: float, z: float, ox: float, oy: float, oz: float) -> String:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return "no camera"
	var t := get_tree().root.find_child("Terrain", true, false) as _TERRAIN
	var y := 0.0
	if t != null:
		var g: float = t.ground_height(x, z)
		y = 0.0 if is_nan(g) else g
	var look := Vector3(x, y + 1.0, z)
	cam.look_at_from_position(look + Vector3(ox, oy, oz), look, Vector3.UP)
	return "framed (%.0f, %.0f) y %.1f" % [x, z, y]


## Same as frame(), but centred on a target by name (Druid1, Trogg1, Druid2...), for close shots.
func frame_on(n: String, ox: float, oy: float, oz: float) -> String:
	var b := _find(n)
	if b == null:
		return "no %s" % n
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return "no camera"
	var look := b.global_transform.origin + Vector3(0, 1.0, 0)
	cam.look_at_from_position(look + Vector3(ox, oy, oz), look, Vector3.UP)
	return "framed %s at (%.0f, %.0f)" % [n, look.x, look.z]
