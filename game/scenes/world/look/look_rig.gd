@tool
class_name LookRig
extends Node

## Holds the look layers of a map: one line in the world scene (`%Look`). Each layer is a packed
## scene under `Layers`; removing one removes that layer. Presentation only: a dedicated or
## headless process frees the whole rig. No autoloads, so it also runs in the editor.
## It carries the profile, the quality preset and the map nodes layers act on (sun, Environment).
## Layers are `LookLayer` nodes: the rig hands them the profile and the preset.

signal profile_applied(profile: LookProfile)
signal layer_toggled(index: int, enabled: bool)

const GODS: Array[StringName] = [&"persephone", &"pyro", &"james", &"stratos", &"charnel"]

@export_group("Editor preview")
@export_enum("persephone", "pyro", "james", "stratos", "charnel") var preview_god: String = "persephone"
@export_tool_button("Vista previa del bioma") var _preview_action: Callable = preview

@export_group("Sockets")
@export var layers: Node
@export var quality: QualityApplier
## Map nodes the light layer drives; set where the rig is instanced in the world scene.
@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
## The map's terrain (a `terrain.gd` MeshInstance3D) the ground layer gives its material to.
@export var terrain: MeshInstance3D
## The map's original sky (`sky.tscn`): the sky layer keeps it (Legacy) or swaps it (Swirl).
@export var legacy_sky: Node3D
## Which `GroundSet` slot paints each of the map's tile ids. The classic ground (a biome without a
## PBR `GroundSet`) uses it so the grass knows where it grows; it belongs to the map, not to a biome.
@export var tile_map: TileLayerMap

var profile: LookProfile
## Last preset handed to `apply_quality` (or the one the Quality socket holds).
var quality_preset: LookQuality


func _ready() -> void:
	if not Engine.is_editor_hint() and _is_presentationless():
		queue_free()
		return
	if quality and quality.quality:
		quality_preset = quality.quality
		_push_quality()


func apply_profile(new_profile: LookProfile) -> void:
	profile = new_profile
	for layer in _look_layers():
		layer.apply_look(profile, self)
	profile_applied.emit(profile)


## Quality preset for the viewport and for every layer. Debug tools and menus call this.
func apply_quality(preset: LookQuality) -> void:
	quality_preset = preset
	if quality:
		quality.quality = preset
	_push_quality()


## Editor button: shows the preview god's profile through the layers, with the god's atlas under
## the classic ground (what `ThemeApplier.apply` does in the game).
func preview() -> void:
	var god := StringName(preview_god)
	var theme_path := "res://data/themes/%s.tres" % god
	if terrain and terrain.has_method("set_tileset_dir") and ResourceLoader.exists(theme_path):
		var theme: Resource = load(theme_path)
		if theme and theme.has_method("resolved"):
			var resolved: Resource = theme.call("resolved")
			terrain.call("set_tileset_dir", resolved.call("dir"))
	apply_profile(LookApplier.profile_for(god))


func _push_quality() -> void:
	for layer in _look_layers():
		layer.apply_quality(quality_preset)


func _look_layers() -> Array[LookLayer]:
	var found: Array[LookLayer] = []
	for node in layer_nodes():
		if node is LookLayer:
			found.append(node)
	return found


func layer_nodes() -> Array[Node]:
	var found: Array[Node] = []
	if layers:
		found.assign(layers.get_children())
	return found


func set_layer_enabled(index: int, enabled: bool) -> void:
	var nodes := layer_nodes()
	if index < 0 or index >= nodes.size():
		return
	nodes[index].set("visible", enabled)
	layer_toggled.emit(index, enabled)


## Bit i is set while layer i is on (layers that cannot hide count as on).
func layer_mask() -> int:
	var mask := 0
	var nodes := layer_nodes()
	for i in nodes.size():
		var shown: Variant = nodes[i].get("visible")
		if shown == null or bool(shown):
			mask |= 1 << i
	return mask


func _is_presentationless() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	var kit := get_node_or_null("/root/MpKit")
	return kit != null and kit.has_method("is_dedicated") and bool(kit.call("is_dedicated"))


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if layers == null:
		warnings.append("Falta el socket Layers.")
	if sun == null or world_environment == null:
		warnings.append("Faltan los sockets Sun / World Environment: la capa de luz no actua sin ellos.")
	if terrain == null:
		warnings.append("Falta el socket Terrain: la capa de suelo no actua sin el.")
	return warnings
