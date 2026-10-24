extends RefCounted

## RFC-061g cases of rules_suite: the five walls (Firewall, Wall of Spikes, Wailing Wall, Vinewall, Fence) through WallAction, SpellWall,
## WallTouch, FencePosts and FenceZap. The maths of a wall on its own, the scenes, how the ends grow and stop, how long a wall stands, what
## each one does to what is inside (the numbers of 061R), the cast that is cut and what the AI does with them. No network: the server paths
## run as solo. Time is the physics tick, so a wall of 35 s runs in `--fixed-fps 600` quickly. `run(host)` adds its own world and removes it.

const WORLD := preload("res://debug/suite/soul_world.gd")
const WALLS := {"lwrf": "pyro", "laws": "james", "laww": "charnel", "lawv": "persephone", "cnef": "stratos"}
const KINDS := {"lwrf": "Firewall", "laws": "WallOfSpikes", "laww": "WailingWall", "lawv": "Vinewall", "cnef": "Fence"}
const SCENES := {"Firewall": "firewall", "WallOfSpikes": "wall_of_spikes", "WailingWall": "wailing_wall", "Vinewall": "vinewall", "Fence": "fence"}
const HEIGHTS := {"lwrf": 7.5, "laws": 5.0, "laww": 7.5, "lawv": 7.5, "cnef": 5.5}
## The colour of the light each wall carries: the exe's orange for the Firewall, the dominant of the picture for the rest.
const LIGHTS := {"lwrf": Color(1, 0.5, 0), "laws": Color(0.75, 0.55, 0.35), "laww": Color(0.8, 0.4, 0.28), "lawv": Color(0.5, 0.72, 0.25), "cnef": Color(0.7, 0.55, 1)}
const CLICK := Vector3(0.0, 0.0, 30.0)
const TICKS := 60.0

var _w := WORLD.new()


func run(host: Node3D) -> Dictionary:
	_w.build(host, "WallCases")
	var spawner := _w.root.get_node("SpellSpawner") as SpellSpawner
	for kind in KINDS.values():
		spawner.zones[kind] = load("res://scenes/spells/walls/%s.tscn" % SCENES[kind]) as PackedScene
	var out := {}
	out["wall_rules"] = _rules()
	out["wall_scenes"] = _scenes()
	out["wall_fire"] = await _fire()
	out["wall_building"] = await _building()
	out["wall_spikes"] = await _spikes()
	out["wall_wailing"] = await _wailing()
	out["wall_vines"] = await _vines()
	out["wall_fence"] = await _fence()
	out["wall_cancel"] = await _cancel()
	out["wall_refusals"] = await _refusals()
	out["wall_ai"] = _ai()
	_w.clear()
	return out


## The maths on its own: the way it runs, how tall it stands, the slope of its ends, the ramp and isInWall.
func _rules() -> Dictionary:
	var checks := {}
	var run := WallRules.direction_for(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), Vector3.FORWARD)
	checks["perpendicular"] = absf(run.dot(Vector2(1.0, 0.0))) < 0.0001 and is_equal_approx(run.length(), 1.0)
	checks["click_on_the_wizard_uses_his_facing"] = WallRules.direction_for(Vector3.ZERO, Vector3.ZERO, Vector3(0.0, 0.0, 1.0)).is_equal_approx(Vector2(0.0, 1.0))
	checks["yaw_turns_x_onto_the_way"] = Basis(Vector3.UP, WallRules.yaw_of(run)).x.is_equal_approx(Vector3(run.x, 0.0, run.y))
	checks["rises_in_its_time"] = WallRules.rise(0, 120, -1, 60) == 0.0 and is_equal_approx(WallRules.rise(60, 120, -1, 60), 0.5) and WallRules.rise(500, 120, -1, 60) == 1.0
	checks["sinks_in_one_second"] = is_equal_approx(WallRules.rise(630, 120, 600, 60), 0.5) and WallRules.rise(660, 120, 600, 60) == 0.0
	checks["sinks_from_where_it_was"] = is_equal_approx(WallRules.rise(75, 120, 60, 60), 0.25) and WallRules.rise(90, 120, 60, 60) == 0.0
	checks["ends_slope_over_5m"] = is_equal_approx(WallRules.edge_scale(5.0, 0.0, 100.0), 1.0) and is_equal_approx(WallRules.edge_scale(2.5, 0.0, 100.0), 0.5) and WallRules.edge_scale(-1.0, 0.0, 100.0) == 0.0
	checks["ramp"] = WallRules.ramp(100, 120, 180) == 0.0 and is_equal_approx(WallRules.ramp(210, 120, 180), 0.5) and WallRules.ramp(400, 120, 180) == 1.0
	var box := AABB(Vector3(-0.3, 0.0, 29.7), Vector3(0.6, 1.8, 0.6))
	var dir := Vector2(1.0, 0.0)
	var centre := Vector3(0.0, 0.0, 30.0)
	checks["inside"] = WallRules.in_wall(box, 0.0, 7.5, centre, dir, -20.0, 20.0, 5.0)
	checks["beside_it"] = not WallRules.in_wall(AABB(Vector3(-0.3, 0.0, 33.7), Vector3(0.6, 1.8, 0.6)), 0.0, 7.5, centre, dir, -20.0, 20.0, 5.0)
	checks["touching_the_thickness"] = WallRules.in_wall(AABB(Vector3(-0.3, 0.0, 32.2), Vector3(0.6, 1.8, 0.6)), 0.0, 7.5, centre, dir, -20.0, 20.0, 5.0)
	checks["past_the_end"] = not WallRules.in_wall(AABB(Vector3(21.0, 0.0, 29.7), Vector3(0.6, 1.8, 0.6)), 0.0, 7.5, centre, dir, -20.0, 20.0, 5.0)
	checks["flying_over_it"] = not WallRules.in_wall(AABB(Vector3(-0.3, 8.0, 29.7), Vector3(0.6, 1.8, 0.6)), 0.0, 7.5, centre, dir, -20.0, 20.0, 5.0)
	checks["a_wall_not_yet_risen_is_no_wall"] = not WallRules.in_wall(AABB(Vector3(-0.3, 1.0, 29.7), Vector3(0.6, 1.8, 0.6)), 0.0, 0.0, centre, dir, -20.0, 20.0, 5.0)
	return _w.verdict("wall_rules", checks)


## The scenes are what the spells say: pick the ground, the kind is in the spawner, the box is the SpellType's reach and the wall's height
## and thickness, no configuration warnings, and every wall is in the book of its god.
func _scenes() -> Dictionary:
	var checks := {}
	var match_text := FileAccess.get_file_as_string("res://scenes/match/match.tscn")
	for tag in WALLS:
		var spell := GameData.spell(tag)
		var action := (spell.action.instantiate() as SpellAction) if spell != null and spell.action != null else null
		checks[tag + "_action"] = action is WallAction and _with_tag(action, tag) and action.pick == SpellAction.Pick.GROUND and action._get_configuration_warnings().is_empty()
		var scene := load("res://scenes/spells/walls/%s.tscn" % SCENES[KINDS[tag]]) as PackedScene
		var wall := scene.instantiate() as SpellWall if scene != null else null
		checks[tag + "_kind_in_spawner"] = wall != null and action is WallAction and (action as WallAction).wall_kind == KINDS[tag] and match_text.contains("walls/%s.tscn" % SCENES[KINDS[tag]])
		if wall != null:
			var size := (wall.body.shape as BoxShape3D).size
			checks[tag + "_warnings"] = wall._get_configuration_warnings().is_empty()
			checks[tag + "_box_is_the_spell"] = absf(size.x - 2.0 * spell.effect_range_m) < 0.01 and absf(size.y - HEIGHTS[tag]) < 0.01 and absf(size.z - 5.0) < 0.01
			checks[tag + "_wall_has_the_spell"] = wall.spell == spell
			var touch := wall.get_node_or_null("Touch") as WallTouch
			var light := wall.get_node_or_null("Light") as ActorLight
			checks[tag + "_has_its_light"] = light != null and not light.shadow_enabled and light.light_energy > 0.0
			checks[tag + "_light_colour"] = light != null and light.light_color.is_equal_approx(LIGHTS[tag])
			checks[tag + "_touch_ok"] = tag == "cnef" or (touch != null and touch._get_configuration_warnings().is_empty())
			wall.free()
		if action != null:
			action.free()
		var god := GameData.god(WALLS[tag])
		checks[tag + "_in_the_book"] = god != null and god.book.spells.has(spell)
	return _w.verdict("wall_scenes", checks)


## The Firewall from Pyro: it is born perpendicular to the line wizard -> click, its ends grow to 55 m, it rises to 7.5 m in 2 s, it does
## nothing during the casting, its damage is 625 a second times one ramp of 3 s for the whole wall, and it is gone 30 s + 1 s after it was built.
func _fire() -> Dictionary:
	_clear_walls()
	var checks := {}
	var wizard := _w.wizard(1, Vector3.ZERO, "pyro", 9)
	await _land(wizard)
	var a := _w.unit(CLICK, 3, 500000.0)
	var b := _w.unit(Vector3(200.0, 0.0, 30.0), 3, 500000.0)
	var twin := _w.unit(Vector3(600.0, 0.0, 600.0), 3, 500000.0)
	await _w.frames(3)
	var tick := (twin.get_node("Health") as Health).damage_typed(625.0 / TICKS, Health.DIRECT_SPELL, 1, false, true, Health.IGNITE)
	var caster := wizard.get_node("Caster") as Caster
	caster.request_cast("lwrf", CLICK, null)
	var wall := _wall()
	checks["born_with_the_cast"] = wall != null and wall.age == 0 and not wall.armed and wall.center.distance_to(CLICK) < 0.01
	if wall == null:
		return _w.verdict("wall_fire", checks)
	checks["perpendicular_to_the_line"] = absf(wall.direction.dot(Vector2(CLICK.x, CLICK.z).normalized())) < 0.001
	var ha := a.get_node("Health") as Health
	var hb := b.get_node("Health") as Health
	var last_a := ha.current
	var last_b := hb.current
	var lost_a := {}
	var lost_b := {}
	var armed_age := -1
	var seen := {"top_at_60": 0.0, "top_at_120": 0.0, "left": 0.0, "right": 0.0, "last_age": 0, "damage_before_armed": 0.0}
	var guard := 0
	while is_instance_valid(wall) and guard < 2400:
		await _w.frames(1)
		guard += 1
		if not is_instance_valid(wall):
			break
		var age := wall.age
		seen["last_age"] = age
		if wall.armed and armed_age < 0:
			armed_age = age
		if age == 250:
			b.position = Vector3(10.0, 0.0, 30.0)
		if age == 60:
			seen["top_at_60"] = wall.top()
		if age == 120:
			seen["top_at_120"] = wall.top()
		if age == 250:
			seen["left"] = wall.left
			seen["right"] = wall.right
		lost_a[age] = last_a - ha.current
		lost_b[age] = last_b - hb.current
		last_a = ha.current
		last_b = hb.current
		if armed_age < 0:
			seen["damage_before_armed"] = float(seen["damage_before_armed"]) + float(lost_a[age])
	checks["info"] = seen.merged({"armed_age": armed_age, "tick": tick})
	checks["ends_grow_to_55"] = absf(float(seen["left"]) + 55.0) < 0.3 and absf(float(seen["right"]) - 55.0) < 0.3
	checks["rises_in_2_seconds"] = absf(float(seen["top_at_60"]) - 3.75) < 0.05 and absf(float(seen["top_at_120"]) - 7.5) < 0.05
	checks["nothing_while_casting"] = armed_age > 100 and float(seen["damage_before_armed"]) == 0.0
	var first := _first_age(lost_a)
	checks["ramp_starts_where_the_wall_is_up"] = first >= armed_age and first <= armed_age + 2 and absf(float(lost_a[first]) / tick - float(first - 120) / 180.0) < 0.03
	var window_a := 0.0
	var window_b := 0.0
	for age in range(320, 380):
		window_a += float(lost_a[age])
		window_b += float(lost_b[age])
	checks["625_a_second_when_the_ramp_is_full"] = absf(window_a / (tick * TICKS) - 1.0) < 0.02
	checks["one_ramp_for_the_whole_wall"] = window_b > 0.0 and absf(window_a - window_b) <= 0.01 * window_a
	checks["a_body_outside_is_not_burnt"] = float(lost_b.get(240, 1.0)) == 0.0
	checks["gone_30s_after_it_was_built"] = absi(int(seen["last_age"]) - (240 + 1800 + 60)) <= 2
	for body: Node in [wizard, a, b, twin]:
		body.queue_free()
	return _w.verdict("wall_fire", checks)


## A building on the way stops the end that meets it.
func _building() -> Dictionary:
	_clear_walls()
	var checks := {}
	var house := StaticBody3D.new()
	house.name = "House"
	house.add_to_group(&"structure")
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 4.0, 4.0)
	shape.shape = box
	shape.position = Vector3(0.0, 2.0, 0.0)
	house.add_child(shape)
	_w.root.add_child(house)
	house.position = Vector3(20.0, 0.0, 30.0)
	var wizard := _w.wizard(1, Vector3.ZERO, "pyro", 9)
	await _land(wizard)
	wizard.get_node("Caster").request_cast("lwrf", CLICK, null)
	var wall := _wall()
	await _w.until(func() -> bool: return wall.age >= 260, 600)
	var near := minf(absf(wall.left), absf(wall.right))
	var far := maxf(absf(wall.left), absf(wall.right))
	checks["the_end_that_meets_it_stops"] = near < 40.0
	checks["stops_at_the_wall_of_the_house"] = near > 17.5 and near < 18.2
	checks["the_other_end_keeps_going"] = absf(far - 55.0) < 0.3
	wizard.queue_free()
	house.queue_free()
	return _w.verdict("wall_building", checks)


## The Wall of Spikes from James: whoever steps on its axis is stunned, hurt for the spell's damage and slowed to half for 6 s, once per 6 s;
## the stun and the slowdown do not look at sides; a body past 0.4 of the thickness is left alone; nothing happens while it is cast.
func _spikes() -> Dictionary:
	_clear_walls()
	var checks := {}
	var wizard := _w.wizard(1, Vector3.ZERO, "james", 9)
	await _land(wizard)
	var foe := _w.unit(CLICK, 3, 500000.0)
	var ally := _w.unit(Vector3(12.0, 0.0, 30.0), 2, 500000.0)
	var edge := _w.unit(Vector3(-20.0, 0.0, 32.3), 3, 500000.0)
	var twin := _w.unit(Vector3(600.0, 0.0, 600.0), 3, 500000.0)
	await _w.frames(3)
	var expected := (twin.get_node("Health") as Health).damage_typed(625.0, Health.DIRECT_SPELL, 1)
	var hits: Array[int] = []
	wizard.get_node("Caster").request_cast("laws", CLICK, null)
	var wall := _wall()
	(foe.get_node("Health") as Health).hit.connect(func(_amount: float, _slot: int, _full: bool) -> void: hits.append(wall.age))
	var first_slow := -1
	var last_slow := -1
	var early_stun := false
	var ally_stunned := false
	var edge_stunned := false
	for _i in 900:
		await _w.frames(1)
		if not is_instance_valid(wall):
			break
		if not hits.is_empty() and wall.age == hits[0] + 5:
			foe.position = Vector3(300.0, 0.0, 30.0)
		var pace := PaceFactors.of(foe)
		if pace != null and is_equal_approx(pace.factor_of(&"wall_spikes"), 0.5):
			first_slow = wall.age if first_slow < 0 else first_slow
			last_slow = wall.age
		early_stun = early_stun or (not wall.armed and _w.stunned(foe))
		ally_stunned = ally_stunned or _w.stunned(ally)
		edge_stunned = edge_stunned or _w.stunned(edge)
	checks["info"] = {"expected": expected, "hits": hits.slice(0, 4), "n": hits.size(), "first_slow": first_slow, "last_slow": last_slow}
	checks["quiet_during_the_casting"] = not early_stun and not hits.is_empty() and hits[0] > 100
	checks["625_of_direct_spell"] = expected > 300.0 and hits.size() == 1
	checks["stunned"] = _w.stunned(foe) or ally_stunned
	checks["pace_halves_for_6_seconds"] = first_slow >= 0 and absi((last_slow - first_slow + 1) - 360) <= 2
	checks["touches_again_only_after_6_seconds"] = hits.size() >= 1 and hits[0] <= first_slow + 1
	checks["allies_too"] = ally_stunned
	checks["past_the_core_nothing"] = not edge_stunned and (edge.get_node("Health") as Health).current == 500000.0
	for body: Node in [wizard, foe, ally, edge, twin]:
		body.queue_free()
	return _w.verdict("wall_spikes", checks)


## The Wailing Wall from Charnel: whoever crosses it, ally or foe, is drained of all its mana in a second and slowed to 0.75 for 8 s.
func _wailing() -> Dictionary:
	_clear_walls()
	var checks := {}
	var wizard := _w.wizard(1, Vector3.ZERO, "charnel", 9)
	await _land(wizard)
	var foe := _w.wizard(3, CLICK, "james")
	var ally := _w.wizard(2, Vector3(12.0, 0.0, 30.0), "james")
	await _w.frames(3)
	var foe_pool := foe.get_node("ManaPool") as ManaPool
	var ally_pool := ally.get_node("ManaPool") as ManaPool
	wizard.get_node("Caster").request_cast("laww", CLICK, null)
	var wall := _wall()
	var drained_at := -1
	var armed_at := -1
	var first_slow := -1
	var last_slow := -1
	var ally_empty := false
	for _i in 900:
		await _w.frames(1)
		if not is_instance_valid(wall):
			break
		if wall.armed and armed_at < 0:
			armed_at = wall.age
		if foe_pool.current <= 0.0 and drained_at < 0:
			drained_at = wall.age
		ally_empty = ally_empty or ally_pool.current <= 0.0
		if first_slow >= 0 and wall.age == first_slow + 40:
			foe.position = Vector3(300.0, 0.0, 30.0)
		var pace := PaceFactors.of(foe)
		if pace != null and is_equal_approx(pace.factor_of(&"wall_wailing"), 0.75):
			first_slow = wall.age if first_slow < 0 else first_slow
			last_slow = wall.age
	checks["info"] = {"armed_at": armed_at, "drained_at": drained_at, "first_slow": first_slow, "last_slow": last_slow}
	checks["drained_in_a_second"] = armed_at > 0 and drained_at >= armed_at and drained_at - first_slow <= 62
	checks["allies_too"] = ally_empty
	checks["slow_075_for_8_seconds"] = first_slow >= 0 and absi((last_slow - first_slow + 1) - 480) <= 2
	for body: Node in [wizard, foe, ally]:
		body.queue_free()
	return _w.verdict("wall_wailing", checks)


## The Vinewall from Persephone: a foe that crosses the core is tied with what is left of the wall (the usual share of it), allies are not,
## and the wall waits 6 s after the vines are gone before it ties the same body again.
func _vines() -> Dictionary:
	_clear_walls()
	var checks := {}
	var wizard := _w.wizard(1, Vector3.ZERO, "persephone", 9)
	await _land(wizard)
	var foe := _w.unit(CLICK, 3, 5000.0)
	var ally := _w.unit(Vector3(12.0, 0.0, 30.0), 2, 5000.0)
	await _w.frames(3)
	wizard.get_node("Caster").request_cast("lawv", CLICK, null)
	var wall := _wall()
	var touch := wall.get_node("Touch") as WallTouch
	var tied_at: Array[int] = []
	var asked: Array[float] = []
	touch.touched.connect(func(_body: Node3D) -> void:
		tied_at.append(wall.age)
		asked.append(maxf(0.0, wall.spell.duration_s - float(wall.age - wall.grow_ticks) / TICKS)))
	var on_since := -1
	var runs: Array[Vector2i] = []
	var ally_tied := false
	for _i in 1900:
		await _w.frames(1)
		if not is_instance_valid(wall):
			break
		var on := Vined.is_vined(foe)
		if on and on_since < 0:
			on_since = wall.age
		if not on and on_since >= 0:
			runs.append(Vector2i(on_since, wall.age))
			on_since = -1
		ally_tied = ally_tied or Vined.is_vined(ally)
	checks["info"] = {"tied_at": tied_at, "asked": asked, "runs": runs}
	checks["tied_once_the_casting_is_over"] = not tied_at.is_empty() and tied_at[0] > 100 and runs.size() >= 2
	var expected := ceili(TICKS * (1000.0 / 5000.0) * asked[0]) if not asked.is_empty() else -1
	checks["the_usual_share_of_what_is_left"] = not runs.is_empty() and absi((runs[0].y - runs[0].x) - expected) <= 2
	checks["allies_are_not_tied"] = not ally_tied
	checks["waits_6_seconds_after_the_vines"] = runs.size() >= 2 and absi((runs[1].x - runs[0].y) - 360) <= 3
	for body: Node in [wizard, foe, ally]:
		body.queue_free()
	return _w.verdict("wall_vines", checks)


## The Fence from Stratos: nothing before the casting is over; then two posts at ticks 16, 48 ... 176 (twelve), each at the end of the wall
## of that moment; a foe within 10 m of a post is struck for the spell's damage as lightning, a body 30 m from every post is not.
func _fence() -> Dictionary:
	_clear_walls()
	var checks := {}
	var wizard := _w.wizard(1, Vector3.ZERO, "stratos", 9)
	await _land(wizard)
	var foe := _w.unit(CLICK, 3, 500000.0)
	var far := _w.unit(Vector3(0.0, 0.0, 120.0), 3, 500000.0)
	var twin := _w.unit(Vector3(600.0, 0.0, 600.0), 3, 500000.0)
	await _w.frames(3)
	var expected := (twin.get_node("Health") as Health).damage_typed(625.0, Health.DIRECT_SPELL, 1, false, false, Health.LIGHTNING)
	var hits: Array[float] = []
	(foe.get_node("Health") as Health).hit.connect(func(amount: float, _slot: int, _full: bool) -> void: hits.append(amount))
	wizard.get_node("Caster").request_cast("cnef", CLICK, null)
	var wall := _wall()
	var posts := wall.get_node("Posts") as FencePosts
	var births := {}
	var count := 0
	var early_posts := false
	for _i in 3400:
		await _w.frames(1)
		if not is_instance_valid(wall):
			break
		early_posts = early_posts or (not wall.armed and not posts.posts.is_empty())
		if posts.posts.size() > count:
			count = posts.posts.size()
			births[wall.age] = count
	checks["info"] = {"births": births, "hits": hits.size(), "expected": expected}
	checks["no_posts_while_casting"] = not early_posts
	checks["two_every_32_ticks_from_16"] = births.keys() == [16, 48, 80, 112, 144, 176] and births.values() == [2, 4, 6, 8, 10, 12]
	checks["struck_for_625_of_lightning"] = hits.size() >= 10 and expected > 300.0
	var all_equal := true
	for amount in hits:
		all_equal = all_equal and absf(amount - expected) < 0.5
	checks["every_strike_is_the_spells"] = all_equal
	checks["far_body_is_not_struck"] = (far.get_node("Health") as Health).current == 500000.0
	checks["the_wizard_is_never_struck"] = (wizard.get_node("Health") as Health).current == (wizard.get_node("Health") as Health).maximum
	checks["gone_with_its_time"] = not is_instance_valid(wall)
	for body: Node in [wizard, foe, far, twin]:
		body.queue_free()
	return _w.verdict("wall_fence", checks)


## The wizard dies while casting: the wall sinks at once (the Fence too) and is gone within a second.
func _cancel() -> Dictionary:
	var checks := {}
	for tag in ["lwrf", "cnef"]:
		_clear_walls()
		var wizard := _w.wizard(1, Vector3.ZERO, WALLS[tag], 9)
		await _land(wizard)
		wizard.get_node("Caster").request_cast(tag, CLICK, null)
		var wall := _wall()
		await _w.frames(30)
		(wizard.get_node("Health") as Health).damage(99999.0, 3)
		await _w.frames(3)
		checks[tag + "_sinks_at_once"] = is_instance_valid(wall) and wall.vanish_at >= 0 and wall.vanish_at < 40
		await _w.frames(70)
		checks[tag + "_gone_in_a_second"] = not is_instance_valid(wall) or wall.is_queued_for_deletion()
		wizard.queue_free()
	return _w.verdict("wall_cancel", checks)


## What the five refuse: out of range, no mana; a good point passes.
func _refusals() -> Dictionary:
	var checks := {}
	for tag in WALLS:
		var wizard := _w.wizard(1, Vector3.ZERO, WALLS[tag], 9)
		await _land(wizard)
		var caster := wizard.get_node("Caster") as Caster
		checks[tag + "_good_point"] = caster.action_status(tag, CLICK, null).is_empty()
		checks[tag + "_out_of_range"] = caster.action_status(tag, Vector3(0.0, 0.0, 150.0), null) == SpellAction.OUT_OF_RANGE
		var pool := wizard.get_node("ManaPool") as ManaPool
		pool.current = 0.0
		checks[tag + "_no_mana"] = caster.action_status(tag, CLICK, null) == SpellAction.NO_MANA
		wizard.queue_free()
	return _w.verdict("wall_refusals", checks)


## The AI rates them as areas (the flags of the original) and the rest of the book keeps its evaluator.
func _ai() -> Dictionary:
	var checks := {}
	for tag in WALLS:
		checks[tag + "_rated_as_an_area"] = AiSpellEval.rating_fn(GameData.spell(tag)) == AiSpellEval.FN_AREA
	checks["old_spells_unchanged"] = AiSpellEval.rating_fn(GameData.spell("kcor")) == AiSpellEval.FN_SINGLE
	return _w.verdict("wall_ai", checks)


## The newest wall that stands.
func _wall() -> SpellWall:
	var children := _w.spells.get_children()
	children.reverse()
	for child in children:
		if child is SpellWall and not child.is_queued_for_deletion():
			return child as SpellWall
	return null


## Every case starts with no wall of the one before.
func _clear_walls() -> void:
	for child in _w.spells.get_children():
		if child is SpellWall:
			child.queue_free()


## The first age (key) with a loss above 0.
func _with_tag(action: SpellAction, tag: String) -> bool:
	action.tag = tag
	return true


func _first_age(lost: Dictionary) -> int:
	var ages := lost.keys()
	ages.sort()
	for age: int in ages:
		if float(lost[age]) > 0.0:
			return age
	return -1


func _land(wizard: WizardBody) -> void:
	await _w.until(func() -> bool: return wizard.is_on_floor(), 180)
