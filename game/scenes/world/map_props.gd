extends Node3D

## The map content: player starts and manafounts are nodes of the scene (Starts, Founts).
## This node hands the match rules down to their ManaSource children and places the plants.
## Plants stand where the High Noon NTTS widget list puts them (sacengine placeWidgets,
## state.d:31346): one per entry, skipped over holes, height from the land.

const ALTAR_GROUP := &"altar"
const FOUNT_GROUP := &"manafount"

@export var plant_scene: PackedScene
## Fallback models for a widget tag missing from widget_models.
@export var plant_models: PackedStringArray = PackedStringArray()
## Map widget tag (JAW1…) → plant models drawn for it. The map is James land; the look is Persephone.
@export var widget_models: Dictionary = {}
@export_file("*.json") var widgets_path := "res://cache/high_noon_widgets.json"
@export var plant_seed := 17
@export var altar_clear := 40.0
@export var fount_clear := 6.0


## Debug scenes swap `rules` on the scene root. The mana sources of the map read theirs in
## _ready, so they get the root's rules here, before any child is ready.
func _enter_tree() -> void:
	var rules: Variant = owner.get("rules") if owner else null
	if not rules is MatchRules:
		return
	for source in find_children("ManaSource", "Node3D", true, false):
		source.set("rules", rules)


func _ready() -> void:
	_place_widgets()


func _place_widgets() -> void:
	if plant_scene == null or not BodyLibrary.loads_meshes():
		return
	var terrain := GroundGuard.terrain_of(self)
	var widgets := _read_widgets()
	if terrain == null or widgets.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = plant_seed
	var placed := 0
	var tags := widgets.keys()
	tags.sort()
	for tag in tags:
		var models: PackedStringArray = widget_models.get(tag, plant_models)
		if models.is_empty():
			continue
		for row in widgets[tag]:
			var model := models[rng.randi() % models.size()]
			var x := float(row[0])
			var z := float(row[1])
			if not terrain.call("is_on_ground", x, z) or not _is_clear(Vector3(x, 0.0, z)):
				continue
			var plant: Node3D = plant_scene.instantiate()
			plant.set("model", model)
			plant.name = "Plant%d" % placed
			add_child(plant)
			# The NTTS angle looks like degrees but sacengine reads it as radians (state.d:31352).
			plant.global_position = Vector3(x, float(terrain.call("ground_height", x, z)), z)
			plant.rotation.y = float(row[2])
			placed += 1


func _read_widgets() -> Dictionary:
	if not FileAccess.file_exists(widgets_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(widgets_path))
	return parsed if parsed is Dictionary else {}


func _is_clear(at: Vector3) -> bool:
	return _far_from(ALTAR_GROUP, at, altar_clear) and _far_from(FOUNT_GROUP, at, fount_clear)


func _far_from(group: StringName, at: Vector3, clear: float) -> bool:
	for node in get_tree().get_nodes_in_group(group):
		var prop := node as Node3D
		if prop and _flat_distance(at, prop.global_position) < clear:
			return false
	return true


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
