extends Node

## Observation only (024b2 network test): what a client sees of the villages. report() counts the bodies under %Units,
## the NPC among them, the map buildings, the shelters and the state of the jhut of (1255, 1214).

func report() -> String:
	var root := get_tree().current_scene
	var units := root.find_child("Units", true, false) if root else null
	var npc := 0
	var farmers := 0
	var taurocks := 0
	var cowering := 0
	if units != null:
		for body in units.get_children():
			if body.is_in_group("npc"):
				npc += 1
			var tag := str(body.get("creature_tag"))
			if tag == "zepe":
				farmers += 1
			elif tag == "raeb":
				taurocks += 1
			if int(body.get("mode")) == UnitBody.Mode.COWER:
				cowering += 1
	var buildings := get_tree().get_nodes_in_group("map_building")
	var hut_text := "sin jhut"
	for node in buildings:
		var spot := (node as Node3D).global_transform.origin
		if str(node.get("tag")) == "jhut" and Vector2(spot.x, spot.z).distance_to(Vector2(1255.0, 1214.0)) < 3.0:
			var body := node as CollisionObject3D
			var shape := node.get_node("Collision") as CollisionShape3D
			hut_text = "jhut(1255,1214) hp=%s/%s destruida=%s visible=%s en_refugios=%s capa=%d colision_off=%s" % [
				node.get_node("Health").get("current"), node.get_node("Health").get("maximum"), node.is_destroyed(),
				node.get_node("Visuals").get("visible"), node.is_in_group("shelter"), body.collision_layer, shape.disabled]
	return "Units=%d npc=%d farmers=%d taurocks=%d cowering=%d edificios=%d refugios=%d %s" % [
		units.get_child_count() if units else -1, npc, farmers, taurocks, cowering, buildings.size(),
		get_tree().get_nodes_in_group("shelter").size(), hut_text]
