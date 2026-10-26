@tool
class_name LookRig
extends Node

## Holds the look layers of a map: one line in the world scene (`%Look`). Each layer is a packed
## scene or a node under `Layers`; removing one removes that layer. It also holds the world's sun and
## Environment inside their layers, and the empty slots time of day and weather will fill.
## The rig hands every `LookLayer` the profile and the quality preset; the layer works out its own
## object from them. Presentation only: a dedicated or headless process frees the whole rig. Runs in the editor too.

signal profile_applied(profile: LookProfile)
signal layer_toggled(index: int, enabled: bool)
## The player's «Vegetación» switch changed; the vegetation layers listen.
signal vegetation_toggled(enabled: bool)

@export_group("Editor preview")
## Pick a god and the map shows its look in the editor, live (sky, light, glow, ground, plants). Empty = the map as it is.
## Editor only: in the running game it is ignored and the match's god wins.
@export var preview_god: GodType:
	set(value):
		preview_god = value
		if Engine.is_editor_hint() and is_node_ready():
			_show_preview()
## The preset the editor preview wears (without one, FloraField plants nothing). Editor only.
@export var preview_quality: LookQuality = preload("res://data/look/quality_high.tres"):
	set(value):
		preview_quality = value
		if Engine.is_editor_hint() and is_node_ready():
			_show_preview()

@export_group("Sockets")
@export var layers: Node
@export var quality: QualityApplier
## The sun layer, for tools that turn the sun by hand.
@export var sun_layer: SunLayer
## The map's ground; the node that draws it (`terrain.mesh`) is what the ground layer dresses.
@export var terrain: Terrain
## Which `GroundSet` slot paints each of the map's tile ids. The classic ground (a biome without a
## PBR `GroundSet`) uses it so the grass knows where it grows; it belongs to the map, not to a biome.
@export var tile_map: TileLayerMap
## The ground of a map made of one god's land (empty for the other maps): a look of that god wears it.
@export var native_ground: NativeGround

var profile: LookProfile
## Last preset handed to `apply_quality` (or the one the Quality socket holds).
var quality_preset: LookQuality
## The player's «Vegetación» switch (GraphicsPrefs, through GraphicsApplier): off, the mesh vegetation draws nothing
## whatever the preset says. On by default (the editor, debug scenes).
var vegetation_enabled := true


func _ready() -> void:
	if not Engine.is_editor_hint() and is_presentationless():
		queue_free()
		return
	if quality and quality.quality:
		quality_preset = quality.quality
		_push_quality()
	if Engine.is_editor_hint() and preview_god != null:
		_show_preview.call_deferred()


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


func set_vegetation_enabled(on: bool) -> void:
	if on == vegetation_enabled:
		return
	vegetation_enabled = on
	vegetation_toggled.emit(on)


## Editor only: the preview god's profile through the layers, with the preview preset. Nothing of it is saved: the layers
## draw it from the profile each time.
func _show_preview() -> void:
	if quality and preview_quality != null:
		apply_quality(preview_quality)
	apply_profile(preview_god.look if preview_god != null else null)


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


## True in a headless or dedicated process, where nothing of the look is drawn (the rig, and every actor light, frees itself).
static func is_presentationless() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	var tree := Engine.get_main_loop() as SceneTree
	var kit := tree.root.get_node_or_null("/root/MpKit") if tree else null
	return kit != null and kit.has_method("is_dedicated") and bool(kit.call("is_dedicated"))  # dynamic: the MpKit autoload has no class_name and is absent in the editor


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if layers == null:
		warnings.append("Falta el socket Layers.")
	if terrain == null:
		warnings.append("Falta el socket Terrain (el Terrain del mapa): la capa de suelo no actua sin el.")
	return warnings
