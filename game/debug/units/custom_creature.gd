extends Node

## RFC-051 (F330+): a creature of the user's own, made from a Blender .glb with tools/bake/new_creature.gd, plays a whole life in a
## match. `testmonster` (assets/custom/models/testmonster.glb, made by tools/blender/make_test_creature.py) is NOT in any real book:
## this test adds it to the in-memory book of Pyro before the wizard reads it (the file data/gods/pyro.tres stays as it is).
##   1. the wizard summons it from the book;
##   2. it walks to a MOVE order (the rules read its run speed, no clip data needed);
##   3. it fights a dummy that does not die: the swings play both melee variants of the model (`attack_at45` and `attack2_at60`, F336)
##      and each blow lands at the impact its clip's name carries (45 % of 40 frames = 0.6 s; 60 % of 50 frames = 1.0 s), not at the end of
##      the clip nor at the default middle; the dummy loses health;
##   3b. its HUD icon (F335, assets/custom/icons/testmonster.png) is the `icon` of its CreatureType (the roster and the book read it), 32 x 32, not the original's;
##   4. it dies and its corpse settles;
##   5. its model scene maps the roles to the .glb clips and the death role really lays the skeleton down (the rig is inert on a
##      headless run, so the scene is driven by hand, the way BodyRig drives it).
## Nothing here reads assets/original/models/index.json. Prints CUSTOM_CREATURE PASS or CUSTOM_CREATURE FAIL <reason>.
## Sin ventana: `--headless --fixed-fps 600 res://debug/units/custom_creature.tscn`.

const TAG := "testmonster"
const GOD := "pyro"
const SLOT := 1
const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const MAX_WAIT_FRAMES := 1800
## UnitOrders.Command (the enum of a script with no class_name).
const ORDER_MOVE := 1
const ORDER_ATTACK := 2
## The blow lands this many seconds after the swing starts, by variant: the `hit` marker at frame 18 of the 30 fps `attack_at45`, frame 30 of `attack2_at60`.
const IMPACT_S: Array[float] = [0.6, 1.0]
const IMPACT_TOLERANCE_S := 0.08

## One entry per swing of the fight: {index: the swing it played, start: frame it started, hit: frame its blow landed or -1}.
var _swings: Array[Dictionary] = []
var _frame := 0


func _ready() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame
		_frame += 1


func _fail(reason: String) -> void:
	print("CUSTOM_CREATURE FAIL %s" % reason)
	get_tree().quit(1)


func _wizard() -> Node3D:
	for wizard in get_tree().get_nodes_in_group("wizard"):
		if int(wizard.get("owner_slot")) == SLOT:
			return wizard as Node3D
	return null


func _mine() -> UnitBody:
	for unit in get_tree().get_nodes_in_group(&"unit"):
		if int(unit.get("owner_slot")) == SLOT and str(unit.get("creature_tag")) == TAG:
			return unit as UnitBody
	return null


## The test creature goes into the in-memory book of GOD (the resource is shared by the process; the process ends with the test).
func _add_to_book() -> void:
	var creature := GameData.creature(TAG)
	var god := GameData.god(GOD)
	if creature != null and god != null and god.book != null and not god.book.creatures.has(creature):
		god.book.creatures.append(creature)


func _run() -> void:
	await _frames(30)
	var wizard := _wizard()
	if wizard == null:
		_fail("no wizard in slot %d" % SLOT)
		return
	_add_to_book()
	wizard.set("god", GOD)
	await _frames(2)
	var caster = wizard.get_node("Caster")
	if caster.spellbook.creature_index_of(TAG) < 0:
		_fail("%s is not in the book of %s" % [TAG, GOD])
		return

	# 1. Summon.
	caster.request_summon(TAG)
	var unit: UnitBody = null
	for _i in MAX_WAIT_FRAMES:
		await _frames(1)
		unit = _mine()
		if unit != null and not unit.is_summoning() and not caster.is_casting():
			break
	if unit == null or unit.is_summoning():
		_fail("the creature never appeared (summon feedback?)")
		return
	var info := BodyCatalog.info(TAG)
	var type := unit.type
	var facts := type.clip_facts() if type != null else ClipFacts.of(null)
	var checks := {
		"type_found": type != null and type.model == TAG,
		"scene_exists": BodyModel.exists(TAG),
		"size_height": absf(float(info.get("height", 0.0)) - 2.0) < 0.05,
		"size_reach": absf(float(info.get("reach", 0.0)) - 0.475) < 0.01,
		"melee_clips": facts.frames(&"attack") == 40 and facts.hits(&"attack") == PackedInt32Array([18])
			and facts.frames(&"attack2") == 50 and facts.hits(&"attack2") == PackedInt32Array([30]) and not facts.has(&"attack3"),
		"death_clip": facts.frames(&"death") == 36,
	}
	for key in checks:
		if not checks[key]:
			_fail("summoned creature: %s" % key)
			return
	var icon := _icon_verdict()
	if not icon.is_empty():
		_fail(icon)
		return
	print("CUSTOM_CREATURE summoned %s (%s) at frame %d, hp %.0f" % [unit.display_name(), TAG, _frame, unit.get_node("Health").current])

	# 2. Walk to an order.
	var orders := unit.get_node("Orders")
	unit.idle_aggro = false
	var start := unit.global_position
	var goal := start + Vector3(12.0, 0.0, 0.0)
	orders.give(ORDER_MOVE, null, goal, Vector2.ZERO, 0.0)
	var walked := 0
	for _i in MAX_WAIT_FRAMES:
		await _frames(1)
		walked += 1
		if Vector2(unit.global_position.x - goal.x, unit.global_position.z - goal.z).length() < 1.0:
			break
	var travelled := Vector2(unit.global_position.x - start.x, unit.global_position.z - start.z).length()
	print("CUSTOM_CREATURE walked %.1f m in %d frames (%.1f m/s)" % [travelled, walked, travelled / (walked / 60.0)])
	if travelled < 10.0:
		_fail("it did not walk to the order (%.1f m of 12)" % travelled)
		return

	# 3. Fight a dummy that does not die. Every swing is recorded: the swing (attack, attack2) it plays and when its blow lands.
	var dummy := _dummy(unit.global_position + Vector3(2.5, 0.0, 0.0))
	await _frames(5)
	var dummy_health: Health = dummy.get_node("Health")
	dummy_health.setup(1.0e7)
	var before := dummy_health.current
	var melee: MeleeAttack = unit.find_children("*", "MeleeAttack", true, false)[0]
	melee.connected.connect(func(_target: Node3D, _frozen: bool) -> void:
		if not _swings.is_empty() and int(_swings[-1]["hit"]) < 0:
			_swings[-1]["hit"] = _frame)
	orders.give(ORDER_ATTACK, dummy, dummy.global_position, Vector2.ZERO, 0.0)
	var was_swinging := false
	for _i in MAX_WAIT_FRAMES * 3:
		await _frames(1)
		var swinging := melee.is_swinging()
		if swinging and not was_swinging:
			_swings.append({"index": melee.swing_index(), "start": _frame, "hit": -1})
		was_swinging = swinging
		if _landed(0) >= 1 and _landed(1) >= 1:
			break
	for index in 2:
		var times := PackedStringArray()
		for swing in _swings:
			if int(swing["index"]) == index and int(swing["hit"]) >= 0:
				times.append("%.3f" % (float(int(swing["hit"]) - int(swing["start"])) / 60.0))
		print("CUSTOM_CREATURE variant %d (%s): %d swings, %d blows landed, after the swing started (s): %s (impact %.2f s)" % [
			index, type.clips.get_animation(MeleeAttack.SWING_ROLES[index]).resource_name, _count(index), _landed(index), ", ".join(times), IMPACT_S[index]])
	if _landed(0) < 1 or _landed(1) < 1:
		_fail("both melee variants must land a blow (swings %d of the first, %d of the second; blows %d and %d; dummy %.0f of %.0f)" % [
			_count(0), _count(1), _landed(0), _landed(1), dummy_health.current, before])
		return
	for swing in _swings:
		if int(swing["hit"]) < 0:
			continue
		var index := int(swing["index"])
		var after_s := float(int(swing["hit"]) - int(swing["start"])) / 60.0
		if absf(after_s - IMPACT_S[index]) > IMPACT_TOLERANCE_S:
			_fail("the blow of variant %d landed at %.3f s, its impact is at %.2f s" % [index, after_s, IMPACT_S[index]])
			return
	if dummy_health.current >= before:
		_fail("the dummy lost no health")
		return

	# 4. Die.
	unit.get_node("Health").damage(1.0e9, 2)
	await _frames(120)
	var corpse := unit.get_node("Corpse")
	if not (unit.is_dead() and corpse.laid and corpse.is_settled):
		_fail("it did not die and settle (dead %s, laid %s, settled %s)" % [unit.is_dead(), corpse.laid, corpse.is_settled])
		return
	print("CUSTOM_CREATURE died and settled")

	# 5. The model scene: roles -> clips, and the death role lays the skeleton down.
	var verdict := await _model_scene()
	if not verdict.is_empty():
		_fail(verdict)
		return
	print("CUSTOM_CREATURE PASS")
	get_tree().quit(0)


## Swings of the fight that played swing `index`.
func _count(index: int) -> int:
	var count := 0
	for swing in _swings:
		if int(swing["index"]) == index:
			count += 1
	return count


## Blows that landed from a swing of slot `index`.
func _landed(index: int) -> int:
	var count := 0
	for swing in _swings:
		if int(swing["index"]) == index and int(swing["hit"]) >= 0:
			count += 1
	return count


## F335: the roster and the book show `CreatureType.icon`. A creature of your own gets the picture drawn from its model: a 32 x 32 image
## with something drawn on it. "" when it is fine.
func _icon_verdict() -> String:
	var type := GameData.creature(TAG)
	var texture: Texture2D = type.icon if type else null
	if texture == null:
		return "CreatureType.icon of %s is empty (run tools/bake/fill_type_icons.gd or creature_icon.gd)" % TAG
	var image := texture.get_image()
	if image == null or image.get_width() != 32 or image.get_height() != 32:
		return "the icon is not 32 x 32"
	var opaque := 0
	for y in 32:
		for x in 32:
			if image.get_pixel(x, y).a > 0.5:
				opaque += 1
	print("CUSTOM_CREATURE icon: %s, %d x %d, %d of 1024 pixels drawn (book and roster read CreatureType.icon)" % [texture.resource_path, image.get_width(), image.get_height(), opaque])
	if opaque < 300 or opaque > 900:
		return "the icon looks empty or flat (%d of 1024 pixels drawn)" % opaque
	return ""


## A creature of the original to be hit (health from its type, no aggro, never fights back).
func _dummy(at: Vector3) -> UnitBody:
	var type := GameData.creature("raeb")
	var dummy := UNIT_SCENE.instantiate() as UnitBody
	dummy.owner_slot = 2
	dummy.type = GameData.creature("raeb")
	dummy.model = type.model
	dummy.idle_aggro = false
	dummy.target_groups = PackedStringArray()
	dummy.position = at
	get_tree().current_scene.add_child(dummy)
	return dummy


func _model_scene() -> String:
	var packed := load(BodyModel.scene_path(TAG)) as PackedScene
	var model := packed.instantiate() as BodyModel
	add_child(model)
	await _frames(2)
	var mapping := {"idle": "idle", "run": "run", "attack": "attack_at45", "attack2": "attack2_at60", "shoot": "attack_at45", "death": "death"}
	for role: String in mapping:
		if model.tag_for(role) != mapping[role]:
			model.queue_free()
			return "role %s plays %s, expected %s" % [role, model.tag_for(role), mapping[role]]
	if model.has_role("hit") or model.has_role("fly"):
		model.queue_free()
		return "the model has states for roles it has no clip for"
	if model.impact_frame("attack") != 18 or model.frames_of("attack") != 40:
		var got := "%d of %d" % [model.impact_frame("attack"), model.frames_of("attack")]
		model.queue_free()
		return "attack impact %s, expected 18 of 40" % got
	if model.has_role("attack3"):
		model.queue_free()
		return "the model has a state for attack3 and no clip for it"
	if model.impact_frame("attack2") != 30 or model.frames_of("attack2") != 50:
		var second := "%d of %d" % [model.impact_frame("attack2"), model.frames_of("attack2")]
		model.queue_free()
		return "attack2 impact %s, expected 30 of 50" % second
	var skeleton := model.skeleton()
	var hips := skeleton.find_bone("hips")
	var tree := model.tree()
	tree.active = true
	var playback := tree.get(BodyModel.PLAYBACK) as AnimationNodeStateMachinePlayback
	playback.start("idle", true)
	await _frames(30)
	var standing := skeleton.get_bone_pose_rotation(hips)
	playback.start("death", true)
	await _frames(100)  # the clip lasts 1.2 s = 72 frames at 60 fps
	var lying := skeleton.get_bone_pose_rotation(hips)
	var turned := rad_to_deg(standing.angle_to(lying))
	var node_name := String(playback.get_current_node())
	model.queue_free()
	print("CUSTOM_CREATURE death role: state %s, hips turned %.0f degrees from the standing pose" % [node_name, turned])
	if node_name != "death" or turned < 60.0:
		return "the death role did not lay the skeleton down (state %s, %.0f degrees)" % [node_name, turned]
	return ""
