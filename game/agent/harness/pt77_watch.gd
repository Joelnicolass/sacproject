extends Node

## Observation only (024f): what this process sees of the AI match. report() prints the local slot, Wizard2 (where, god),
## the creatures by slot under %Units, the NPC and the banner. watch(slot) frames the world camera on that wizard after
## the game placed it (no actor is touched); watch(0) gives the camera back.

var _slot := 0
var _born_ms := Time.get_ticks_msec()
## What the AI caster said (on this process) and how many times the local HUD line (%Battle.text) changed.
var _ai_said := 0
var _hud_changes := 0
var _hud_last := ""
var _hooked: Object
var _aim_slot := 0
## Creatures of slot 2 under %Units right now, and «si» once there was at least one (pt77_vs_ai waits on it).
var slot2_creatures := 0
var slot2_ok := "no"


func _ready() -> void:
	process_priority = 1000


func watch(slot: int) -> String:
	_slot = slot
	return "watch %d" % slot


## Points the current camera at the first creature of `slot` (it lands at the center of the view, where the flow clicks
## with a drag on %View); aim(0) stops. The camera only: no actor is touched.
func aim(slot: int) -> String:
	_aim_slot = slot
	return "aim %d" % slot


func _creature(slot: int) -> Node3D:
	var world := _world()
	if world == null:
		return null
	for body in world.get_node("%Units").get_children():
		if not body.is_in_group("npc") and int(body.get("owner_slot")) == slot:
			return body as Node3D
	return null


func _world() -> Node:
	var root := get_tree().current_scene
	if root == null:
		return null
	if root.has_node("%Wizards"):
		return root
	return root.find_child("HighNoon", true, false)


func _wizard(slot: int) -> Node3D:
	var world := _world()
	if world == null:
		return null
	for wizard in world.get_node("%Wizards").get_children():
		if int(wizard.get("owner_slot")) == slot:
			return wizard as Node3D
	return null


func _process(_delta: float) -> void:
	_listen()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if _aim_slot > 0:
		var body := _creature(_aim_slot)
		if body != null:
			var spot := body.global_transform.origin + Vector3.UP * 1.0
			cam.global_transform = Transform3D(Basis(), spot + Vector3(-12.0, 10.0, -12.0)).looking_at(spot, Vector3.UP)
		return
	if _slot == 0:
		return
	var points: Array[Vector3] = []
	var world := _world()
	if _slot == -2:
		## watch(-2): the village; the house (jhut) with the most villagers within 40 m, and those villagers.
		var best: Array[Vector3] = []
		for house in world.find_children("Bld*_jhut", "", true, false):
			var near: Array[Vector3] = [(house as Node3D).global_transform.origin]
			for body in world.get_node("%Units").get_children():
				if body.is_in_group("npc") and (body as Node3D).global_transform.origin.distance_to(near[0]) < 40.0:
					near.append((body as Node3D).global_transform.origin)
			if near.size() > best.size():
				best = near
		points = best
	elif _slot < 0:
		## watch(-1): the first villager (a Farmer) and the bodies around it.
		for body in world.get_node("%Units").get_children():
			if body.is_in_group("npc"):
				points.append((body as Node3D).global_transform.origin)
				break
	else:
		var wizard := _wizard(_slot)
		if wizard == null:
			return
		points.append(wizard.global_transform.origin)
		for body in world.get_node("%Units").get_children():
			if not body.is_in_group("npc") and int(body.get("owner_slot")) == _slot:
				var spot := (body as Node3D).global_transform.origin
				if spot.distance_to(points[0]) < 35.0:
					points.append(spot)
	if points.is_empty():
		return
	var center := Vector3.ZERO
	for spot in points:
		center += spot
	center /= points.size()
	var spread := 0.0
	for spot in points:
		spread = maxf(spread, spot.distance_to(center))
	var back := 7.0 + spread * 1.2
	cam.global_transform = Transform3D(Basis(), center + Vector3(-back, back * 0.7, -back)).looking_at(center + Vector3.UP * 1.2, Vector3.UP)


func _listen() -> void:
	var world := _world()
	if world == null:
		return
	slot2_creatures = 0
	for body in world.get_node("%Units").get_children():
		if not body.is_in_group("npc") and int(body.get("owner_slot")) == 2:
			slot2_creatures += 1
	if slot2_creatures > 0:
		slot2_ok = "si"
	var battle := world.find_child("Battle", true, false)
	if battle != null and str(battle.get("text")) != _hud_last:
		_hud_last = str(battle.get("text"))
		_hud_changes += 1
	var w2 := _wizard(2)
	var caster := w2.get_node_or_null("Caster") if w2 != null else null
	if caster != null and caster != _hooked:
		_hooked = caster
		caster.connect("feedback", func(_text: String) -> void: _ai_said += 1)


func report() -> String:
	var world := _world()
	if world == null:
		return "sin mundo"
	var by_slot := {}
	var npc := 0
	for body in world.get_node("%Units").get_children():
		if body.is_in_group("npc"):
			npc += 1
			continue
		var slot := int(body.get("owner_slot"))
		by_slot[slot] = int(by_slot.get(slot, 0)) + 1
	var w2 := _wizard(2)
	var w2_text := "Wizard2 no"
	if w2 != null:
		w2_text = "Wizard2 %s slot=%s god=%s at=%s" % [w2.name, w2.get("owner_slot"), w2.get("god"), str(w2.global_transform.origin.snapped(Vector3.ONE * 0.1))]
	var w1 := _wizard(1)
	var own := _creature(1)
	if w1 != null:
		w2_text += " Wizard1 at=%s" % str(w1.global_transform.origin.snapped(Vector3.ONE * 0.1))
		if own != null:
			w2_text += " criatura1 a %.1f m" % w1.global_transform.origin.distance_to(own.global_transform.origin)
	var c2 := _creature(2)
	if c2 != null:
		w2_text += " criatura2 %s at=%s" % [c2.name, str(c2.global_transform.origin.snapped(Vector3.ONE * 0.1))]
	var banner := world.find_child("MatchResult", true, false)
	var banner_text := ""
	if banner is Label and (banner as Label).is_visible_in_tree():
		banner_text = (banner as Label).text
	return "t=%.1fs local_slot=%d %s criaturas_por_slot=%s npc=%d sides=%d cartel='%s' hud='%s' hud_cambios=%d ia_dijo=%d" % [
		(Time.get_ticks_msec() - _born_ms) / 1000.0, MpKit.local_slot(), w2_text, str(by_slot), npc,
		world.get_node("%AiRoster").get_child_count() if world.has_node("%AiRoster") else -1, banner_text.strip_edges(),
		_hud_last, _hud_changes, _ai_said]
