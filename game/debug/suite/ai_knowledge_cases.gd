extends RefCounted

## 055f f6 case of rules_suite: no difficulty cheats. In each of the three difficulties a perception of side 2 makes its first scan
## and then reads bodies its side does not see: a foe creature near its wizard (on the minimap), one far away and an enemy wizard.
## - The scan takes the wizards and the own creatures always; foe creatures only on the minimap with SIGHT_AND_MAP, none with SIGHT.
## - Health and mana of an unseen body are never the real ones (zero: never seen); it cannot be aimed at.
## - The position: SIGHT keeps where it was; SIGHT_AND_MAP reads the real one on the minimap (near foe, enemy wizard), never the far one.
## - unseen_reads == 0 in all three. Also: map_sight_m equals the minimap's starting view radius, and Hard is SIGHT_AND_MAP.
## Prints AI KNOWLEDGE <difficulty> reads=<n> and the checks that fail.

const UNIT_SCENE := preload("res://scenes/units/unit.tscn")
const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const RIG := preload("res://debug/suite/ai_perception_rig.tscn")
const RULES := preload("res://data/match_rules.tres")
const MINIMAP_VIEW := preload("res://data/ui/minimap/view.tres")
const IDS: Array[String] = ["easy", "normal", "hard"]
const HOME := Vector3(3200.0, 0.0, 3200.0)
const NEAR := Vector3(100.0, 0.0, 0.0)
const FAR := Vector3(600.0, 0.0, 0.0)
const WIZARD_AT := Vector3(900.0, 0.0, 0.0)
const MOVE := Vector3(0.0, 0.0, 20.0)


func run(host: Node3D) -> Dictionary:
	var checks := {}
	var radius := (MINIMAP_VIEW as MinimapView).view_radius_m
	checks["default_is_minimap_radius"] = AiSenses.new().map_sight_m == radius
	for id in IDS:
		var difficulty := AiSeat.difficulty_of(id)
		checks[id + "_loaded"] = difficulty != null
		if difficulty == null:
			continue
		checks[id + "_map_is_minimap_radius"] = difficulty.tactics_or_normal().senses.map_sight_m == radius
		var want: AiDifficulty.Knowledge = AiDifficulty.Knowledge.SIGHT_AND_MAP if id == "hard" else AiDifficulty.Knowledge.SIGHT
		checks[id + "_knowledge"] = difficulty.knowledge == want
		checks.merge(await _reads(host, id, difficulty))
	var failed := PackedStringArray()
	for key: String in checks:
		if not bool(checks[key]):
			failed.append(key)
	for key in failed:
		print("AI KNOWLEDGE   failed " + key)
	return {"ai_knowledge": {"ok": failed.is_empty(), "checks": checks}}


## One difficulty: the first scan, then what the side believes of the bodies it does not see after they moved.
func _reads(host: Node3D, id: String, difficulty: AiDifficulty) -> Dictionary:
	var checks := {}
	var map: bool = difficulty.knowledge == AiDifficulty.Knowledge.SIGHT_AND_MAP
	var perception: AiPerception = RIG.instantiate()
	perception.name = "KnowledgeCases_" + id
	perception.play = AiPlay.make(difficulty, null, AiPlay.normal().age_ticks)
	perception.slot = 2
	var eye := Node3D.new()  # the own wizard: the minimap is drawn around him
	eye.name = "KnowledgeEye_" + id
	host.add_child(eye)
	eye.global_position = HOME
	perception.wizard = eye
	perception.belief.look_from(eye, difficulty.knowledge, perception.play.tactics.senses.map_sight_m)
	host.add_child(perception)
	var own := _unit(host, 2, HOME - NEAR * 2.0, "KnowledgeOwn_" + id)
	var near := _unit(host, 1, HOME + NEAR, "KnowledgeNear_" + id)
	var far := _unit(host, 1, HOME + FAR, "KnowledgeFar_" + id)
	var foe_wizard := _wizard(host, 1, HOME + WIZARD_AT, "KnowledgeWizard_" + id)
	await host.get_tree().process_frame
	perception.scan_global()
	checks[id + "_scan_own"] = perception.find(own) != null
	checks[id + "_scan_wizard"] = perception.find(foe_wizard) != null
	checks[id + "_scan_near"] = (perception.find(near) != null) == map
	checks[id + "_scan_far_never"] = perception.find(far) == null
	## Bodies the side tracked from before (a sighting long gone): what it believes of them once they moved and lost half their health.
	var near_t: AiTrack = perception.find(near) if map else perception.add_node(near, &"scan")
	var far_t: AiTrack = perception.add_node(far, &"scan")
	var wizard_t: AiTrack = perception.find(foe_wizard)
	if near_t == null or far_t == null or wizard_t == null:
		checks[id + "_tracked"] = false
		_free([perception, eye, own, near, far, foe_wizard])
		return checks
	for body: Node3D in [near, far, foe_wizard]:
		body.global_position += MOVE
		var health := body.get_node("Health")
		health.set("current", float(health.get("current")) * 0.5)
	perception.update_nodes(1)
	for pair: Array in [["near", near_t, map], ["far", far_t, false], ["wizard", wizard_t, map]]:
		var key: String = id + "_" + String(pair[0])
		var t: AiTrack = pair[1]
		var real := t.node.global_position
		checks[key + "_unseen"] = not perception.sees(t)
		checks[key + "_health_never_real"] = perception.health_of(t) == Vector2i.ZERO
		checks[key + "_mana_never_real"] = perception.mana_of(t) == Vector2i.ZERO
		checks[key + "_cannot_aim"] = not AiCommandPort.aims(perception, t)
		var at := perception.pos_of(t)
		checks[key + "_position"] = at.is_equal_approx(real) if bool(pair[2]) else at.is_equal_approx(real - MOVE)
	checks[id + "_unseen_reads_zero"] = perception.unseen_reads == 0
	print("AI KNOWLEDGE %s reads=%d tracks=%d" % [id, perception.unseen_reads, perception.tracks.size()])
	_free([perception, eye, own, near, far, foe_wizard])
	return checks


func _unit(host: Node3D, slot: int, at: Vector3, title: String) -> Node3D:
	var type := GameData.creature("ycro")
	var unit: Node3D = UNIT_SCENE.instantiate()
	unit.name = title
	unit.position = at
	unit.set("owner_slot", slot)
	unit.set("type", type)
	unit.set("model", type.model_id())
	unit.set("rules", RULES)
	unit.set("idle_aggro", false)
	host.add_child(unit)
	(unit.get("vision") as Vision).watching = false
	return unit


func _wizard(host: Node3D, slot: int, at: Vector3, title: String) -> WizardBody:
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.name = title
	wizard.owner_slot = slot
	wizard.god_type = GameData.god("james")
	wizard.position = at
	host.add_child(wizard)
	wizard.god_type = GameData.god("james")
	return wizard


static func _free(nodes: Array) -> void:
	for node: Node in nodes:
		if is_instance_valid(node):
			node.queue_free()
