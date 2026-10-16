extends Node

## Observation helper for the F113 playtest (RFC-030 030b, bench res://debug/f111_bestiary.tscn).
## Never moves an actor, never changes a rule, never calls into the product to act. It only:
##   start()        listens to signals: own creatures' hits/shots, enemy deaths, souls; times frames after a summon.
##   book()         read-only line: the wizard's book (count + tags) and the HUD creature cells.
##   set_mode(m)    re-frames the screen camera after the bench placed it ("duel": own creature and its foe,
##                  "soul": close-up of the last enemy corpse, "": hand it back). Like a player scrolling the view.
##   aim_own()      the world camera's debug pointer (what `select` / `order_units` read) goes on the newest own creature.
##   aim_enemy()    the pointer goes on the live enemy nearest to it.
##   report()       read-only summary line.
## Props for wait_until: hits_total, deaths, souls, own_alive.

var hits := 0
var shots := 0
var hits_total := 0
var deaths := 0
var souls := 0
var own_alive := 0
## 1 once an enemy or the own creature died (the fight is decided).
var over := 0
var longest_ms := 0.0
var slow_frames := 0
var measured_frames := 0
var baseline := ""
var mode := ""
var last_event := ""

var _own: Node3D
var _foe: Node3D
var _corpse_at := Vector3.ZERO
var _soul_at := Vector3.ZERO
var _soul_slot := -1
var _started := false
var _measure_left := 0
var _last_us := 0
var _order_ms := 0
var _summon_ms := 0
var _origin := Vector3.ZERO
var _times: PackedFloat32Array = []
var _mark := -1
var _track := 0


func _ready() -> void:
	process_priority = 1000


func _world() -> Node:
	var scene := get_tree().current_scene
	return scene.find_child("HighNoon", true, false) if scene else null


func _pos(node: Node) -> Vector3:
	return (node as Node3D).global_transform.origin


func _wizard() -> Node:
	for node in get_tree().get_nodes_in_group("wizard"):
		if int(node.get("owner_slot")) == 1:
			return node
	return null


func start() -> String:
	var world := _world()
	if world == null:
		return "no world"
	if _started:
		return "already"
	_started = true
	var units := world.get_node("%Units")
	units.child_entered_tree.connect(_on_unit_entered)
	for unit in units.get_children():
		_watch(unit, false)
	var souls_node := world.get_node_or_null("SoulSystem")
	if souls_node:
		souls_node.soul_spawned.connect(_on_soul)
	var names: Array = []
	var wizard := _wizard()
	for unit in units.get_children():
		if int(unit.get("owner_slot")) == 2 and wizard:
			names.append("%s a %.0f m" % [unit.display_name(), _pos(unit).distance_to(_pos(wizard))])
	return "enemigas: " + ", ".join(names)


func _on_unit_entered(unit: Node) -> void:
	_watch.call_deferred(unit, true)


func _watch(unit: Node, fresh: bool) -> void:
	if not is_instance_valid(unit) or not unit.has_signal("died"):
		return
	var slot := int(unit.get("owner_slot"))
	if slot == 1 and fresh:
		_own = unit as Node3D
		_origin = _pos(unit)
		_summon_ms = Time.get_ticks_msec()
		_mark = maxi(0, _times.size() - 2)
		_measure_left = 240
		own_alive = 1
		for child in unit.get_children():
			if child.has_signal("struck"):
				child.struck.connect(_on_struck)
			if child.has_signal("fired"):
				child.fired.connect(_on_fired)
		unit.died.connect(_on_own_died)
		print("PT113 convocada %s en %s" % [unit.display_name(), _pos(unit)])
	elif slot == 2:
		unit.died.connect(_on_enemy_died.bind(unit.display_name()))


func _since_order() -> float:
	return (Time.get_ticks_msec() - _order_ms) / 1000.0 if _order_ms > 0 else -1.0


func _walked() -> float:
	return _pos(_own).distance_to(_origin) if is_instance_valid(_own) else -1.0


func _on_struck(target: Node3D, amount: float, _chance: float, _roll: float) -> void:
	hits += 1
	hits_total += 1
	if hits_total == 1:
		print("PT113 primer golpe a %s %.1f, %.1f s tras la orden, caminó %.0f m" % [target.display_name() if target and target.has_method("display_name") else "?", amount, _since_order(), _walked()])


func _on_fired(target: Node3D, damage: float, _a: float, _b: float) -> void:
	shots += 1
	hits_total += 1
	if hits_total == 1:
		print("PT113 primer disparo a %s %.1f, %.1f s tras la orden, caminó %.0f m" % [target.display_name() if target and target.has_method("display_name") else "?", damage, _since_order(), _walked()])


func _on_own_died(_tag: String, _slot: int, at: Vector3) -> void:
	own_alive = 0
	over = 1
	print("PT113 muere la propia en %s, %.1f s tras la orden" % [at, _since_order()])


func _on_enemy_died(_tag: String, _slot: int, at: Vector3, who: String) -> void:
	deaths += 1
	over = 1
	_corpse_at = at
	last_event = "muere %s" % who
	print("PT113 muere enemiga %s en %s, %.1f s tras la orden" % [who, at, _since_order()])


func _on_soul(soul: Node3D) -> void:
	souls += 1
	_soul_at = _pos(soul)
	_soul_slot = int(soul.get("owner_slot"))
	var flat := Vector2(_soul_at.x - _corpse_at.x, _soul_at.z - _corpse_at.z).length()
	print("PT113 alma owner_slot=%d en %s, a %.1f m del último cadáver enemigo" % [_soul_slot, _soul_at, flat])


func book() -> String:
	var wizard := _wizard()
	if wizard == null:
		return "sin mago"
	var spellbook := wizard.get_node("Spellbook")
	var tags: Array = []
	for i in spellbook.creature_count():
		tags.append(str(spellbook.creature_at(i).tag))
	var hud := get_tree().current_scene.find_child("SpellBook", true, false)
	var cells := hud.get_node("Slots").get_child_count() if hud else -1
	return "nivel %s dios %s: libro %d [%s] · casillas HUD %d" % [wizard.get("level"), wizard.get("god"), tags.size(), ",".join(tags), cells]


func set_mode(next: String) -> String:
	mode = next
	return mode


func _nearest_foe(from: Vector3) -> Node3D:
	var best: Node3D = null
	var world := _world()
	if world == null:
		return null
	for unit in world.get_node("%Units").get_children():
		if int(unit.get("owner_slot")) != 2 or not unit.has_node("Health"):
			continue
		if float(unit.get_node("Health").get("current")) <= 0.0:
			continue
		if best == null or _pos(unit).distance_to(from) < _pos(best).distance_to(from):
			best = unit as Node3D
	return best


func _point_at(body: Node3D, lift: float) -> String:
	var cam := get_viewport().get_camera_3d()
	var world := _world()
	if cam == null or world == null or body == null:
		return "nada que apuntar"
	var at := _pos(body) + Vector3.UP * lift
	var screen := cam.unproject_position(at)
	var view := get_viewport().get_visible_rect().size
	var inside := not cam.is_position_behind(at) and Rect2(Vector2.ZERO, view).has_point(screen)
	world.get_node("%Camera").set("debug_pointer", screen)
	return "%s en %d,%d %s" % [body.display_name(), screen.x, screen.y, "en pantalla" if inside else "FUERA DE PANTALLA"]


func aim_own(lift: float = 1.0) -> String:
	return _point_at(_own, lift)


func aim_enemy(lift: float = 1.0) -> String:
	var from := _pos(_own) if is_instance_valid(_own) else _pos(_wizard())
	_foe = _nearest_foe(from)
	_order_ms = Time.get_ticks_msec()
	return _point_at(_foe, lift)


func _frame_stats() -> void:
	longest_ms = 0.0
	slow_frames = 0
	measured_frames = 0
	if _mark < 0:
		return
	var base_max := 0.0
	var base_sum := 0.0
	var base_n := 0
	for i in range(maxi(0, _mark - 240), _mark):
		base_max = maxf(base_max, _times[i])
		base_sum += _times[i]
		base_n += 1
	baseline = "antes de convocar: %d cuadros, media %.1f ms, más largo %.1f ms" % [base_n, base_sum / maxf(1.0, base_n), base_max]
	for i in range(_mark, mini(_times.size(), _mark + 242)):
		longest_ms = maxf(longest_ms, _times[i])
		measured_frames += 1
		if _times[i] > 25.0:
			slow_frames += 1


func _trace() -> void:
	var foe_hp := -1.0
	if is_instance_valid(_foe) and _foe.has_node("Health"):
		foe_hp = float(_foe.get_node("Health").get("current"))
	var at := _pos(_own) if is_instance_valid(_own) else Vector3.ZERO
	print("PT113 t=%.0f s propia en (%.0f, %.0f) caminó %.0f m · golpes %d disparos %d · enemiga %s vida %.0f" % [_since_order(), at.x, at.z, _walked(), hits, shots, _foe.display_name() if is_instance_valid(_foe) else "-", foe_hp])


func aim_ground(ahead_m: float = 15.0) -> String:
	var cam := get_viewport().get_camera_3d()
	var world := _world()
	if cam == null or world == null or not is_instance_valid(_own):
		return "sin cámara o criatura"
	var from := _pos(_own)
	var foe := _nearest_foe(from)
	var dir := (_pos(foe) - from) if foe else Vector3(0, 0, -1)
	dir.y = 0.0
	dir = dir.normalized()
	var spot := from + dir * ahead_m
	var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 200.0, spot + Vector3.DOWN * 400.0)
	query.collision_mask = 1
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return "sin suelo"
	var point: Vector3 = hit["position"]
	var screen := cam.unproject_position(point)
	world.get_node("%Camera").set("debug_pointer", screen)
	_order_ms = Time.get_ticks_msec()
	return "suelo (%.0f, %.0f) en %d,%d" % [point.x, point.z, screen.x, screen.y]


func report() -> String:
	if _measure_left == 0:
		_frame_stats()
	var line := "golpes %d disparos %d muertas %d almas %d" % [hits, shots, deaths, souls]
	if is_instance_valid(_own):
		var health := _own.get_node("Health")
		line += " · propia %s %d/%d en %s, caminó %.0f m" % [_own.display_name(), roundi(float(health.get("current"))), roundi(float(health.get("maximum"))), _pos(_own), _walked()]
	var wizard := _wizard()
	if wizard:
		line += " · mago vida %d" % roundi(float(wizard.get_node("Health").get("current")))
	line += " · cuadro más largo tras convocar %.1f ms, %d de %d cuadros > 25 ms" % [longest_ms, slow_frames, measured_frames]
	return line


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		_times.append((now - _last_us) / 1000.0)
	_last_us = now
	if _measure_left > 0:
		_measure_left -= 1
		if _measure_left == 0:
			_frame_stats()
			print("PT113 cuadros tras convocar: más largo %.1f ms, %d de %d > 25 ms · %s" % [longest_ms, slow_frames, measured_frames, baseline])
	if _order_ms > 0 and Engine.get_process_frames() % 120 == 0:
		_trace()
	if mode == "":
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if (mode == "duel" or mode == "wide") and is_instance_valid(_own):
		var foe := _foe if is_instance_valid(_foe) else _nearest_foe(_pos(_own))
		if foe == null:
			return
		var a := _pos(_own)
		var b := _pos(foe)
		var ahead := b - a
		ahead.y = 0.0
		var span := ahead.length()
		ahead = ahead.normalized() if span > 0.1 else Vector3(0, 0, -1)
		if mode == "wide" or span < 22.0:
			var look := a.lerp(b, 0.5)
			var side := ahead.rotated(Vector3.UP, 2.2)
			var reach := clampf(span, 8.0, 90.0)
			cam.look_at_from_position(look + side * (reach * 0.6 + 8.0) + Vector3.UP * (reach * 0.35 + 5.0), look + Vector3.UP * 1.0, Vector3.UP)
		else:
			var side := ahead.rotated(Vector3.UP, 2.6)
			cam.look_at_from_position(a + side * 14.0 + Vector3.UP * 7.0, a + ahead * 12.0 + Vector3.UP * 1.5, Vector3.UP)
	elif mode.begins_with("soul") and deaths > 0:
		var center := _soul_at if _soul_slot == 2 else _corpse_at
		var offset := Vector3(5.0, 3.5, 5.0)
		if mode == "soul_top":
			offset = Vector3(1.5, 7.0, 2.5)
		elif mode == "soul_other":
			offset = Vector3(-5.0, 3.0, -4.0)
		cam.look_at_from_position(center + offset, center, Vector3.UP)
