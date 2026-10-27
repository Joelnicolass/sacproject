extends RefCounted

## 055x x1 case of rules_suite: an effect is a typed Resource and the network id is its path.
##   - round_trip: every ParticleType and BeamType under data/fx (and its folders) goes id -> resource -> the same object, no empty id;
##   - foreign_ids: an id that is not an effect (no res://, a ShakeMap, nothing) comes back null;
##   - empty_says_nothing: FxBus with no effect (null) says nothing and instances nothing (055x x7 closed the text door);
##   - camera_trauma: the 9 ParticleTypes and the 4 FxScene roots carry the shake the old table gave them; ShakeMap keeps only the fall-off;
##   - played_headless: FxBus says `played` with the Resource and instances nothing (a headless process has no pool children);
##   - sockets: BodyFacts.point puts the four sockets of a body without a mount where its default says, rotated with the body.
## Every case returns {ok, ...}; a failing one prints the values. Prints FX WIRE <case>=<bool>.

const FX_DIR := "res://data/fx/"
const BLOOD := "res://data/fx/blood.tres"
const LIGHTNING := "res://data/fx/beams/lightning.tres"
const FALLING_CHUNK := "res://scenes/map/terrain/falling_chunk.tscn"
const SHAKE_MAP := "res://data/fx/shake_map.tres"
const PARTICLE_TRAUMA := {
	"wrath_explosion1": 0.45, "wrath_explosion2": 0.25, "halo_emerge": 0.3, "cow_ground": 0.25, "cow_rocks_up": 0.4,
	"cow_burst": 0.6, "meteor_hit": 0.6, "meteor_emerge": 0.25, "fireball_blast": 0.2,
}
const SCENE_TRAUMA := {
	"res://scenes/fx/quake_ring.tscn": 0.5, "res://scenes/spells/zones/explosion_burst.tscn": 0.5,
	"res://scenes/spells/zones/erupt_burst.tscn": 0.8, "res://scenes/map/terrain/falling_chunk.tscn": 0.15,
}


func run(host: Node) -> Dictionary:
	var results: Dictionary[String, Dictionary] = {
		"round_trip": _round_trip(),
		"foreign_ids": _foreign_ids(),
		"empty_says_nothing": _empty_says_nothing(),
		"camera_trauma": _camera_trauma(),
		"played_headless": _played_headless(host),
		"sockets": _sockets(host),
	}
	var ok := true
	for case_name: String in results:
		var passed: bool = results[case_name].get("ok", false)
		ok = ok and passed
		print("FX WIRE %s=%s" % [case_name, passed])
	return {"fx_wire": {"ok": ok, "cases": results}}


func _round_trip() -> Dictionary:
	var total := 0
	var empty := 0
	var broken := PackedStringArray()
	for found: Resource in FxWire.all_in(FX_DIR):
		if not (found is ParticleType or found is BeamType):
			continue
		total += 1
		var id: String = FxWire.id_of(found)
		if id.is_empty():
			empty += 1
		elif FxWire.resource(id) != found:
			broken.append(id)
	var passed: bool = total > 100 and empty == 0 and broken.is_empty()
	if not passed:
		print("FX WIRE   round trip: total=%d empty=%d broken=%s" % [total, empty, broken])
	return {"ok": passed, "total": total, "empty": empty, "broken": broken.size()}


func _foreign_ids() -> Dictionary:
	var no_scheme: bool = FxWire.resource("blood") == null
	var empty: bool = FxWire.resource("") == null
	var not_an_effect: bool = FxWire.resource(SHAKE_MAP) == null
	var passed := no_scheme and empty and not_an_effect
	return {"ok": passed, "no_scheme": no_scheme, "empty": empty, "not_an_effect": not_an_effect}


func _empty_says_nothing() -> Dictionary:
	var heard: Array[StringName] = []
	var listener := func(kind: StringName, _fx: Resource, _at: Vector3) -> void:
		heard.append(kind)
	FxBus.played.connect(listener)
	FxBus.play(null, Vector3.ZERO)
	FxBus.puff(null, Vector3.ZERO)
	FxBus.broadcast(null, Vector3.ZERO)
	FxBus.play_beam(null, Vector3.ZERO, Vector3.ONE)
	FxBus.broadcast_beam(null, Vector3.ZERO, Vector3.ONE)
	FxBus.play_scene(null, Vector3.ZERO, {})
	FxBus.broadcast_scene(null, Vector3.ZERO, {})
	FxBus.played.disconnect(listener)
	var passed: bool = heard.is_empty()
	if not passed:
		print("FX WIRE   empty: heard=%s" % [heard])
	return {"ok": passed, "heard": heard.size()}


func _camera_trauma() -> Dictionary:
	var wrong := PackedStringArray()
	for fx_name: String in PARTICLE_TRAUMA:
		var type := load(FX_DIR + fx_name + ".tres") as ParticleType
		if type == null or not is_equal_approx(type.camera_trauma, float(PARTICLE_TRAUMA[fx_name])):
			wrong.append(fx_name)
	for path: String in SCENE_TRAUMA:
		var scene := load(path) as PackedScene
		if scene == null or not is_equal_approx(FxScene.trauma_of(scene), float(SCENE_TRAUMA[path])):
			wrong.append(path.get_file())
	var map := load(SHAKE_MAP) as ShakeMap
	var table_gone: bool = map != null and not ("trauma_by_fx" in map)
	var wrath := load(FX_DIR + "wrath_explosion1.tres") as ParticleType
	var near: bool = map != null and is_equal_approx(map.trauma_of(FxBus.KIND_BURST, wrath, 0.0), 0.45)
	var falls: bool = map != null and is_equal_approx(map.trauma_of(FxBus.KIND_BURST, wrath, 24.0), 0.45 * 16.0 / 32.0)
	var far: bool = map != null and map.trauma_of(FxBus.KIND_BURST, wrath, 40.0) == 0.0
	var puff: bool = map != null and map.trauma_of(FxBus.KIND_PUFF, wrath, 0.0) == 0.0
	var passed := wrong.is_empty() and table_gone and near and falls and far and puff
	if not passed:
		print("FX WIRE   trauma: wrong=%s table_gone=%s near=%s falls=%s far=%s puff=%s" % [wrong, table_gone, near, falls, far, puff])
	return {"ok": passed, "wrong": wrong.size(), "table_gone": table_gone}


func _played_headless(host: Node) -> Dictionary:
	var heard: Array[Dictionary] = []
	var listener := func(kind: StringName, fx: Resource, at: Vector3) -> void:
		heard.append({"kind": kind, "fx": fx, "at": at})
	FxBus.played.connect(listener)
	var scene_children_before: int = host.get_tree().current_scene.get_child_count() if host.get_tree().current_scene != null else 0
	var blood := load(BLOOD) as ParticleType
	var lightning := load(LIGHTNING) as BeamType
	var chunk := load(FALLING_CHUNK) as PackedScene
	FxBus.play(blood, Vector3(1.0, 0.0, 2.0))
	FxBus.puff(blood, Vector3.ZERO)
	FxBus.play_beam(lightning, Vector3.ZERO, Vector3(0.0, 0.0, 10.0))
	FxBus.play_scene(chunk, Vector3(5.0, 0.0, 0.0), {"vertex": 0})
	FxBus.played.disconnect(listener)
	var kinds: PackedStringArray = []
	for row: Dictionary in heard:
		kinds.append(String(row["kind"]))
	var said: bool = kinds == PackedStringArray(["burst", "puff", "beam", "scene"])
	var carries_resource: bool = said and heard[0]["fx"] == blood and heard[2]["fx"] == lightning and heard[3]["fx"] == chunk
	var at_ok: bool = said and (heard[0]["at"] as Vector3) == Vector3(1.0, 0.0, 2.0) and (heard[2]["at"] as Vector3).is_equal_approx(Vector3(0.0, 0.0, 5.0))
	var headless: bool = DisplayServer.get_name() == "headless"
	var bursts: Node = FxBus.get_node("%Bursts")
	var beams: Node = FxBus.get_node("%Beams")
	var scene_children_after: int = host.get_tree().current_scene.get_child_count() if host.get_tree().current_scene != null else 0
	var nothing_instanced: bool = not headless or (bursts.get_child_count() == 0 and beams.get_child_count() == 0 and scene_children_after == scene_children_before)
	var passed := said and carries_resource and at_ok and nothing_instanced
	if not passed:
		print("FX WIRE   played: kinds=%s carries=%s at=%s nothing_instanced=%s" % [kinds, carries_resource, at_ok, nothing_instanced])
	return {"ok": passed, "kinds": kinds, "headless": headless}


func _sockets(host: Node) -> Dictionary:
	var body := Node3D.new()
	host.add_child(body)
	body.global_position = Vector3(3.0, 0.0, 0.0)
	body.rotate_y(PI * 0.5)
	var facts := BodyFacts.fallback()
	var wrong := PackedStringArray()
	for index: int in 4:
		var socket := index as BodyFacts.Socket
		var expected: Vector3 = body.global_transform * facts.local(socket)
		if not BodyFacts.point(body, socket).is_equal_approx(expected):
			wrong.append(str(index))
	var local_ok: bool = facts.local(BodyFacts.Socket.FEET) == facts.feet and facts.local(BodyFacts.Socket.CENTER) == facts.center \
		and facts.local(BodyFacts.Socket.TOP) == facts.top and facts.local(BodyFacts.Socket.MUZZLE) == facts.muzzle
	## Turned a quarter, the muzzle (in front of the body, +z) points along +x: it sits to the side of the center.
	var muzzle: Vector3 = BodyFacts.point(body, BodyFacts.Socket.MUZZLE)
	var turns: bool = muzzle.x > 3.0 + facts.reach_m * 0.9 and absf(muzzle.z) < 0.01
	body.free()
	var passed := wrong.is_empty() and local_ok and turns
	if not passed:
		print("FX WIRE   sockets: wrong=%s local_ok=%s turns=%s muzzle=%s" % [wrong, local_ok, turns, muzzle])
	return {"ok": passed, "wrong": wrong.size()}
