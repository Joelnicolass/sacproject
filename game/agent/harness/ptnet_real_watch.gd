extends Node

## ptnet_real (2026-10-26): observer and pointer of the windowed network playtest (agent/runs/run_ptnet_real_*.sh).
## Idle unless the process has `--ptnet-name=<who>`. It never moves, orders, damages or spawns anything: it reads the world,
## puts the world camera's `debug_pointer` (the cursor that `select` / `order_units` / a cast read) on a spot that is on screen,
## and reads/writes plain marker files so two windows and the run script can wait for each other.
##   aim_ground(x, z)        cursor on the ground point (x, z).
##   aim_wizard(slot)        cursor on the wizard of that slot (+1 m).
##   aim_unit(slot, tag)     cursor on the live unit of that slot (and creature tag, "" = any) nearest to the local wizard.
##   aim_tower(slot)         cursor on the tower (Manalith / Shrine) of that slot.
##   aim_fount(x, z)         cursor on the free manafount nearest to (x, z).
##   aim_soul(not_slot)      cursor on the free soul nearest to the local wizard that is not of `not_slot` (0 = any).
##   aim_corpse_or_unit(slot) cursor on the own unit nearest to the local wizard (a sacrifice target).
##   book()                  the local book: index per tab (creature / spell / structure) with the tags.
##   snap(label)             one PTNET line with the full state (also printed every EVERY_S seconds of wall time).
##   mark(label)             writes <dir>/<who>.<label> (other processes wait for it).
##   expect(file)            remembers a marker file; the prop `seen` turns true once it exists (wait_until prop seen).
##   gap_to(x, z)            remembers a spot; the prop `gap` is the local wizard's flat distance to it.
## Props for wait_until: seen (bool), gap (m), live_units (own live units), mana (own), towers_up (standing towers of all),
## started (MatchClock > 0 and a world).

const EVERY_S := 5.0

var who := ""
var dir := ""
var seen := false
var gap := 9999.0
var live_units := 0
var mana := 0.0
var souls := 0
var towers_up := 0
## The highest build_progress of the local side's towers (0 = none, 1 = standing).
var tower_progress := 0.0
var started := false
## The local wizard can act (alive, not a ghost).
var alive := false
## The «Esperando jugadores k/n» banner (Hud/MatchWait): shown on screen, and its text.
var banner := false
var banner_text := ""
## The local player is back at the boot screen (Play/Join visible) and the boot status text.
var at_boot := false
var boot_status := ""

var _expect := ""
var _spot := Vector2.ZERO
var _has_spot := false
var _next_auto := 0.0
## The world camera's flat forward (x, z): where the player looks.
## Flat distance from the local wizard to the nearest free soul of another side (9999 = none).
var enemy_soul_gap := 9999.0
## Degrees between where the camera looks and the spot given to face_to (0..180; 999 = none).
var face_err := 999.0
## Health of the building given to watch_building (-1 once it is destroyed or gone).
var bld_hp := -1.0
var _face := Vector2.ZERO
var _has_face := false
var _bld: Node3D
var cam_fx := 0.0
var cam_fz := 0.0
var _poll := 0.0
var _log: Node


func _ready() -> void:
	who = MpBoot.user_value("ptnet-name", "")
	dir = MpBoot.user_value("ptnet-dir", "")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(not who.is_empty())
	var deadline := float(MpBoot.user_value("ptnet-deadline-s", "0"))
	if not who.is_empty() and deadline > 0.0:
		get_tree().create_timer(deadline, true, false, true).timeout.connect(_on_deadline)


func _on_deadline() -> void:
	print("PTNET %s deadline: quitting" % who)
	get_tree().quit(3)


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.2
	if not _expect.is_empty():
		seen = FileAccess.file_exists(_expect)
	var me := _local_wizard()
	started = me != null and MatchClock.now() > 0
	_read_banner()
	_hook_log()
	var cam := _world_camera()
	if cam != null:
		var ahead := -cam.global_transform.basis.z
		var flat := Vector2(ahead.x, ahead.z).normalized()
		cam_fx = flat.x
		cam_fz = flat.y
		if _has_face and me != null:
			var at := _at(me)
			var want := (_face - Vector2(at.x, at.z)).normalized()
			face_err = rad_to_deg(absf(flat.angle_to(want)))
	bld_hp = -1.0
	if _valid(_bld) and not (_bld as MapBuilding).is_destroyed():
		bld_hp = _hp(_bld)
	if me != null:
		var at := _at(me)
		gap = Vector2(at.x, at.z).distance_to(_spot) if _has_spot else 9999.0
		var pool := me.get_node_or_null("ManaPool")
		mana = float(pool.get("current")) if pool != null else 0.0
		var purse := me.get_node_or_null("SoulPurse")
		souls = int(purse.get("count")) if purse != null else 0
		live_units = _units_of(int(me.get("owner_slot"))).size()
		alive = _hp(me) > 0.0 and not (me is WizardBody and (me as WizardBody).is_ghost())
		enemy_soul_gap = 9999.0
		for node in get_tree().get_nodes_in_group("soul"):
			if _valid(node) and int(node.get("collector_slot")) == 0 and int(node.get("owner_slot")) != int(me.get("owner_slot")):
				var sp := _at(node)
				enemy_soul_gap = minf(enemy_soul_gap, Vector2(sp.x, sp.z).distance_to(Vector2(at.x, at.z)))
	towers_up = 0
	tower_progress = 0.0
	var mine := MpKit.local_slot()
	for t in _towers():
		if not (t as CastTower).is_destroyed():
			towers_up += 1
			if int(t.get("owner_slot")) == mine:
				tower_progress = maxf(tower_progress, float(t.get("build_progress")))
	var now := Time.get_unix_time_from_system()
	if me != null and now >= _next_auto:
		_next_auto = now + EVERY_S
		snap("auto")


## The player's battle log (%Battle, CommandLog): what the game tells the player (refusals, prompts) goes to stdout too.
func _hook_log() -> void:
	if _valid(_log) or get_tree().current_scene == null:
		return
	var found := get_tree().current_scene.find_child("Battle", true, false)
	if found == null or not found.has_signal("said"):
		return
	_log = found
	found.connect("said", func(text: String, _cue: StringName) -> void: print("PTNET %s said %s tick=%d" % [who, text, MatchClock.now()]))
	found.connect("armed_changed", func(kind: String, _icon: Texture2D) -> void: print("PTNET %s armed %s tick=%d" % [who, kind, MatchClock.now()]))


func _read_banner() -> void:
	var scene := get_tree().current_scene
	var shown := false
	var text := ""
	var status := ""
	var boot := false
	if scene != null:
		var wait := scene.find_child("MatchWait", true, false) as Control
		if wait != null:
			shown = wait.is_visible_in_tree()
			var count := wait.find_child("Count", true, false) as Label
			text = count.text if count != null else ""
		var play := scene.find_child("Join", true, false) as Control
		boot = play != null and play.is_visible_in_tree()
		var label := scene.find_child("Status", true, false) as Label
		status = label.text if label != null and boot else ""
	if shown != banner or text != banner_text:
		print("PTNET %s banner visible=%s text=%s tick=%d" % [who, str(shown), text, MatchClock.now()])
	if boot != at_boot or status != boot_status:
		print("PTNET %s boot visible=%s status=%s" % [who, str(boot), status])
	banner = shown
	banner_text = text
	at_boot = boot
	boot_status = status


# --- reading ---------------------------------------------------------------------------------------------------------

func _valid(node: Variant) -> bool:
	return node != null and is_instance_valid(node) and (node as Node).is_inside_tree()


func _at(node: Node) -> Vector3:
	return (node as Node3D).global_transform.origin


func _local_wizard() -> Node3D:
	if get_tree().current_scene == null:
		return null
	return get_tree().get_first_node_in_group("local_wizard") as Node3D


func _health(node: Node) -> Node:
	return node.get_node_or_null("Health")


func _hp(node: Node) -> float:
	var h := _health(node)
	return float(h.get("current")) if h != null else -1.0


func _alive(node: Node) -> bool:
	return _hp(node) > 0.0


func _tag(node: Node) -> String:
	if "creature_tag" in node:
		return str(node.get("creature_tag"))
	return "?"


func _units_of(slot: int) -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("unit"):
		if _valid(node) and int(node.get("owner_slot")) == slot and _alive(node) and not node.is_in_group("wizard"):
			out.append(node)
	return out


func _wizard_of(slot: int) -> Node3D:
	for node in get_tree().get_nodes_in_group("wizard"):
		if _valid(node) and int(node.get("owner_slot")) == slot:
			return node as Node3D
	return null


func _towers() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("map_building"):
		if _valid(node) and node is CastTower:
			out.append(node)
	return out


func _terrain_text() -> String:
	var scene := get_tree().current_scene
	var terrain: Terrain = Terrain.of(scene) if scene != null else null
	if terrain == null or not terrain.is_loaded():
		return "terrain=none"
	var field := terrain.field()
	return "terrain rev=%d ver=%d sum=%d holes=%d live=%d" % [field.rev, field.version, field.checksum(), field.removed_ids().size(), field.live_keys().size()]


func _wizards_text() -> String:
	var parts := PackedStringArray()
	var list := get_tree().get_nodes_in_group("wizard")
	list.sort_custom(func(a: Node, b: Node) -> bool: return int(a.get("owner_slot")) < int(b.get("owner_slot")))
	for node in list:
		if not _valid(node):
			continue
		var p := _at(node)
		var pool := node.get_node_or_null("ManaPool")
		var purse := node.get_node_or_null("SoulPurse")
		parts.append("w%d %s@%.1f,%.1f hp=%.0f mana=%.0f souls=%d ghost=%s" % [int(node.get("owner_slot")), node.name, p.x, p.z,
			_hp(node), float(pool.get("current")) if pool != null else -1.0, int(purse.get("count")) if purse != null else -1,
			str((node as WizardBody).is_ghost()) if node is WizardBody else "?"])
	return " | ".join(parts)


func _units_text(detail: bool) -> String:
	var by_slot := {}
	for node in get_tree().get_nodes_in_group("unit"):
		if not _valid(node) or node.is_in_group("wizard") or not _alive(node):
			continue
		var slot := int(node.get("owner_slot"))
		if not by_slot.has(slot):
			by_slot[slot] = []
		by_slot[slot].append(node)
	var parts := PackedStringArray()
	var slots := by_slot.keys()
	slots.sort()
	for slot in slots:
		var list: Array = by_slot[slot]
		list.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))
		if detail:
			var each := PackedStringArray()
			for node in list:
				var p := _at(node)
				each.append("%s:%s@%.1f,%.1f:%.0f" % [node.name, _tag(node), p.x, p.z, _hp(node)])
			parts.append("u%d[%s]" % [slot, " ".join(each)])
		else:
			var total := 0.0
			for node in list:
				total += _hp(node)
			parts.append("u%d n=%d hp=%.0f" % [slot, list.size(), total])
	return " | ".join(parts) if not parts.is_empty() else "units=0"


func _towers_text() -> String:
	var parts := PackedStringArray()
	for t in _towers():
		var p := _at(t)
		parts.append("T%d %s@%.0f,%.0f hp=%.0f prog=%.2f down=%s" % [int(t.get("owner_slot")), t.name, p.x, p.z, _hp(t), float(t.get("build_progress")), str(t.is_destroyed())])
	return "towers[%s]" % " ".join(parts)


func _world_text() -> String:
	var souls_free := 0
	var souls_list := PackedStringArray()
	for node in get_tree().get_nodes_in_group("soul"):
		if _valid(node):
			souls_free += 1
			var p := _at(node)
			souls_list.append("%d%s@%.0f,%.0f" % [int(node.get("owner_slot")), "a" if bool(node.get("attached")) else "f", p.x, p.z])
	var corpses := get_tree().get_nodes_in_group("corpse").size()
	var scars := get_tree().get_first_node_in_group("ground_scars")
	var painted := (scars as GroundScars).painted_tiles() if scars is GroundScars else -1
	## 060s: tiles count 10 m squares; `marks` counts every stamp kept (blood, burns, cracks), the number to compare between peers.
	var stamped := (scars as GroundScars).marks.size() if scars is GroundScars else -1
	var ruins := 0
	for node in get_tree().current_scene.find_children("*", "Node3D", true, false) if get_tree().current_scene != null else []:
		if node is BuildingRuin:
			ruins += 1
	var state := get_tree().get_first_node_in_group(MatchState.GROUP) as MatchState
	var defeated := "%s seated=%s" % [str(state.defeated_slots), str(state.seated_slots)] if state != null else "?"
	var ended := str(state.ended) if state != null else "?"
	var sky := "sky=?"
	var atmo := _atmosphere()
	if atmo != null:
		var sample: AtmosphereSample = atmo.current()
		var weather := atmo.get_node_or_null("Weather")
		var w_state: Variant = weather.get("state_now") if weather != null else null
		sky = "sky t=%.1f hour=%.2f night=%.2f weather=%s" % [atmo.now_s(), sample.hour, sample.night,
			(w_state as Resource).resource_path.get_file() if w_state is Resource else "?"]
	return "souls=%d[%s] corpses=%d scars=%d marks=%d ruins=%d defeated=%s ended=%s %s" % [souls_free, " ".join(souls_list), corpses, painted, stamped, ruins, defeated, ended, sky]


func _atmosphere() -> Atmosphere:
	if get_tree().current_scene == null:
		return null
	for node in get_tree().current_scene.find_children("*", "Atmosphere", true, false):
		return node as Atmosphere
	return null


func snap(label: String) -> String:
	if get_tree().current_scene == null:
		return "no scene"
	var detail := label != "auto"
	var line := "PTNET %s %s wall=%.2f tick=%d slot=%d | %s | %s | %s | %s | %s" % [who, label, Time.get_unix_time_from_system(),
		MatchClock.now(), MpKit.local_slot(), _terrain_text(), _wizards_text(), _units_text(detail), _towers_text(), _world_text()]
	print(line)
	return line


func roots() -> String:
	var names := PackedStringArray()
	for child in get_tree().root.get_children():
		names.append(String(child.name))
	var line := "PTNET %s roots %s current=%s" % [who, ",".join(names), get_tree().current_scene.name if get_tree().current_scene else "-"]
	print(line)
	return line


func book() -> String:
	var me := _local_wizard()
	if me == null:
		return "no wizard"
	var sb: Spellbook = me.get_node_or_null("Spellbook") as Spellbook
	if sb == null:
		return "no spellbook"
	var parts := PackedStringArray()
	var c := PackedStringArray()
	for i in sb.creature_count():
		c.append("%d:%s" % [i + 1, sb.creature_at(i).tag])
	var s := PackedStringArray()
	for i in sb.size():
		var spell: SpellType = sb.spell_at(i)
		s.append("%d:%s" % [i + 1, spell.tag if spell != null else "-"])
	var st := PackedStringArray()
	for i in sb.structure_count():
		var spell: SpellType = sb.structure_at(i)
		st.append("%d:%s" % [i + 1, spell.tag if spell != null else "-"])
	parts.append("creatures " + " ".join(c))
	parts.append("spells " + " ".join(s))
	parts.append("structures " + " ".join(st))
	var line := "PTNET %s book %s" % [who, " | ".join(parts)]
	print(line)
	return line


# --- pointer ---------------------------------------------------------------------------------------------------------

func _world_camera() -> Camera3D:
	if get_tree().current_scene == null:
		return null
	for node in get_tree().current_scene.find_children("*", "Camera3D", true, false):
		if "debug_pointer" in node:
			return node as Camera3D
	return null


func _point_at(spot: Vector3, what: String, want: Node = null, any_body := false) -> String:
	var cam := _world_camera()
	if cam == null:
		return "aim %s: no camera" % what
	## A click lands on the first body along the ray (layers 1+2, like PointerRay): try a few spots on the target until the
	## ray hits it (a body) or hits no body (the ground), so an own creature in front does not take the click.
	var tries: Array[Vector3] = [Vector3.ZERO]
	if want != null:
		tries = [Vector3.ZERO, Vector3.UP * 1.0, Vector3.UP * 2.0, Vector3.UP * -0.5, Vector3.UP * 3.0, Vector3(0.6, 0.5, 0.0), Vector3(-0.6, 0.5, 0.0), Vector3(0.0, 0.5, 0.6), Vector3(0.0, 0.5, -0.6)]
	var seen := PackedStringArray()
	for offset in tries:
		var point := spot + offset
		if cam.is_position_behind(point):
			seen.append("behind")
			continue
		var screen := cam.unproject_position(point)
		if not cam.get_viewport().get_visible_rect().has_point(screen):
			seen.append("off screen %d,%d" % [int(screen.x), int(screen.y)])
			continue
		var under := _under(cam, screen)
		var ok := any_body or (under == want) or (want != null and under != null and want.is_ancestor_of(under))
		if not ok:
			seen.append("hits %s" % (String(under.name) if under != null else "ground"))
			continue
		cam.set("debug_pointer", screen)
		var line := "PTNET %s aim %s at %d,%d (%.1f, %.1f, %.1f) under=%s" % [who, what, int(screen.x), int(screen.y), point.x, point.y, point.z,
			String(under.name) if under != null else "ground"]
		print(line)
		return line
	var miss := "PTNET %s aim %s: no clear spot (%s)" % [who, what, ", ".join(seen)]
	print(miss)
	return miss


## The body under a screen point (layers 1+2 like a click), or null for the ground / nothing.
func _under(cam: Camera3D, screen: Vector2) -> Node:
	var origin := cam.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + cam.project_ray_normal(screen) * 10000.0)
	query.collision_mask = 3
	## The game's clicks skip the own wizard (PointerRay.body_under(screen, true)).
	var me := _local_wizard()
	if me is CollisionObject3D:
		query.exclude = [(me as CollisionObject3D).get_rid()]
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var col := hit["collider"] as Node
	return col if col != null and "owner_slot" in col else null


## The player's mouse resting in the middle of the view (not on an edge, where the camera would turn by itself).
func pointer_center() -> String:
	var cam := _world_camera()
	if cam == null:
		return "pointer: no camera"
	var size := cam.get_viewport().get_visible_rect().size
	cam.set("debug_pointer", size * 0.5)
	return "pointer center %d,%d" % [int(size.x * 0.5), int(size.y * 0.5)]


func pointer_off() -> String:
	var cam := _world_camera()
	if cam != null:
		cam.set("debug_pointer", Vector2(-1.0, -1.0))
	return "pointer off"


func aim_ground(x: float, z: float) -> String:
	var scene := get_tree().current_scene
	var terrain: Terrain = Terrain.of(scene) if scene != null else null
	if terrain == null:
		return "aim ground: no terrain"
	var y := terrain.height_at(x, z)
	return _point_at(Vector3(x, 0.0 if is_nan(y) else y, z), "ground %.0f,%.0f" % [x, z])


func aim_wizard(slot: int) -> String:
	var w := _wizard_of(slot)
	if w == null:
		return "aim wizard %d: none" % slot
	return _point_at(_at(w) + Vector3.UP, "wizard %d" % slot, w)


func aim_unit(slot: int, tag: String) -> String:
	var me := _local_wizard()
	var from := _at(me) if me != null else Vector3.ZERO
	var found: Array = []
	for node in _units_of(slot):
		if tag.is_empty() or _tag(node) == tag:
			found.append([_at(node).distance_to(from), node])
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var last := "aim unit %d %s: none" % [slot, tag]
	## The nearest one a click would hit (another body in front of it would take the click): try them in order.
	for pair in found:
		var body := pair[1] as Node3D
		last = _point_at(_at(body) + Vector3.UP, "unit %s#%d" % [body.name, slot], body)
		if not last.contains("no clear spot"):
			return last
	return last


func aim_tower(slot: int) -> String:
	for t in _towers():
		if int(t.get("owner_slot")) == slot and not t.is_destroyed():
			return _point_at(_at(t) + Vector3.UP * 4.0, "tower %s#%d" % [t.name, slot], t)
	return "aim tower %d: none" % slot


func aim_fount(x: float, z: float) -> String:
	var best: Node3D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("manafount"):
		if not _valid(node):
			continue
		var p := _at(node)
		var d := Vector2(p.x, p.z).distance_to(Vector2(x, z))
		if d < best_d:
			best_d = d
			best = node
	if best == null:
		return "aim fount: none"
	return _point_at(_at(best) + Vector3.UP * 0.5, "fount %s" % best.name, null, true)


func aim_soul(not_slot: int) -> String:
	var me := _local_wizard()
	var from := _at(me) if me != null else Vector3.ZERO
	var found: Array = []
	for node in get_tree().get_nodes_in_group("soul"):
		if not _valid(node) or int(node.get("collector_slot")) != 0:
			continue
		if not_slot != 0 and int(node.get("owner_slot")) == not_slot:
			continue
		found.append([_at(node).distance_to(from), node])
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var cam := _world_camera()
	if cam == null or found.is_empty():
		return "aim soul: none"
	## A soul click is the soul's own pick shape (layer 4, group soul_target: PointerRay.soul_under): aim at it and check the ray.
	for pair in found:
		var soul := pair[1] as Node3D
		var target: Node3D = null
		for child in soul.find_children("*", "CollisionObject3D", true, false):
			if child.is_in_group("soul_target"):
				target = child as Node3D
		var spot := target.global_transform.origin if target != null else _at(soul)
		for lift: float in [0.0, 0.5, -0.3, 1.0]:
			var point: Vector3 = spot + Vector3.UP * lift
			if cam.is_position_behind(point):
				continue
			var screen := cam.unproject_position(point)
			if not cam.get_viewport().get_visible_rect().has_point(screen):
				continue
			var origin := cam.project_ray_origin(screen)
			var query := PhysicsRayQueryParameters3D.create(origin, origin + cam.project_ray_normal(screen) * 10000.0)
			query.collision_mask = 4
			var hit := cam.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit["collider"] is Node and (hit["collider"] as Node).is_in_group("soul_target") and soul.is_ancestor_of(hit["collider"] as Node):
				cam.set("debug_pointer", screen)
				var line := "PTNET %s aim soul %s#%d at %d,%d (%.1f, %.1f, %.1f) %.1f m" % [who, soul.name, int(soul.get("owner_slot")), int(screen.x), int(screen.y), point.x, point.y, point.z, float(pair[0])]
				print(line)
				return line
	var miss := "PTNET %s aim soul: no clear spot on %d souls" % [who, found.size()]
	print(miss)
	return miss


func face_to(x: float, z: float) -> String:
	_face = Vector2(x, z)
	_has_face = true
	return "face %.0f,%.0f" % [x, z]


## Cursor on the spot (x, z): the ground there, or whatever body stands on it (a building, a creature).
func aim_point(x: float, z: float) -> String:
	var scene := get_tree().current_scene
	var terrain: Terrain = Terrain.of(scene) if scene != null else null
	if terrain == null:
		return "aim point: no terrain"
	var y := terrain.height_at(x, z)
	return _point_at(Vector3(x, (0.0 if is_nan(y) else y) + 1.0, z), "point %.0f,%.0f" % [x, z], null, true)


## Watches the map building nearest to (x, z): prop bld_hp, and one line with its state.
func watch_building(x: float, z: float) -> String:
	var best: Node3D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("map_building"):
		if not _valid(node) or node is CastTower:
			continue
		var p := _at(node)
		var d := Vector2(p.x, p.z).distance_to(Vector2(x, z))
		if d < best_d:
			best_d = d
			best = node
	_bld = best
	return building()


func building() -> String:
	if not _valid(_bld):
		print("PTNET %s building gone" % who)
		return "gone"
	var ruin := "no-ruin-node"
	for child in _bld.find_children("*", "Node3D", true, false):
		if child is BuildingRuin:
			ruin = "ruin=%s" % ("shown" if (child as BuildingRuin).ruin != null else "none")
	var line := "PTNET %s building %s %s hp=%.0f destroyed=%s visuals=%s %s" % [who, _bld.name, str(_bld.get("tag")), _hp(_bld),
		str((_bld as MapBuilding).is_destroyed()), str(_bld.get_node("Visuals").get("visible")) if _bld.has_node("Visuals") else "?", ruin]
	print(line)
	return line


# --- coordination ----------------------------------------------------------------------------------------------------

func mark(label: String) -> String:
	if dir.is_empty():
		return "no dir"
	var f := FileAccess.open(dir.path_join("%s.%s" % [who, label]), FileAccess.WRITE)
	if f != null:
		f.store_line("%.2f" % Time.get_unix_time_from_system())
		f.close()
	print("PTNET %s mark %s" % [who, label])
	return "mark %s" % label


func expect(file: String) -> String:
	_expect = dir.path_join(file) if not dir.is_empty() else file
	seen = FileAccess.file_exists(_expect)
	return "expect %s (%s)" % [_expect, str(seen)]


func gap_to(x: float, z: float) -> String:
	_spot = Vector2(x, z)
	_has_spot = true
	var me := _local_wizard()
	if me == null:
		return "gap: no wizard"
	var at := _at(me)
	gap = Vector2(at.x, at.z).distance_to(_spot)
	var facing: Vector3 = (me as WizardBody).facing_flat() if me is WizardBody else Vector3.ZERO
	var line := "PTNET %s gap %.1f to %.0f,%.0f from %.1f,%.1f facing %.2f,%.2f camera %.2f,%.2f cam_y %.1f" % [who, gap, x, z, at.x, at.z, facing.x, facing.z, cam_fx, cam_fz,
		_world_camera().global_transform.origin.y - at.y if _world_camera() != null else -1.0]
	print(line)
	return line
