class_name MatchWorld
extends Node3D

signal local_wizard_changed(wizard: Node3D)

## The match is map-agnostic. The map is the child `Map` (a MapRoot) of `map_parent` (World): the one the scene already
## holds (an inherited scene with a map in it) or, when there is none or `--map=<tag>` asks for another, the scene of the
## active MapDefinition. The systems below are bound to its sockets before any of them is ready.
## The children are grouped: World (3D world and spawners), Systems, Input, Hud and Audio.
const MAP_NODE := "Map"

@export var rules: MatchRules
## The group the map is put under, as its first child (World).
@export var map_parent: Node3D
## The systems that take parts of the map when it is attached (set in match.tscn).
@export var camera: WorldCamera
@export var selection: Selection
@export var nav: NavService
## The wizards' MultiplayerSpawner: it takes the map's starts as its spawn points.
@export var wizard_spawner: MpSlotSpawner
@export var population: MapPopulation
@export var graphics_applier: GraphicsApplier
## The match result: when it is known the world stops taking clicks.
@export var match_state: MatchState
## The minimap gets the baked terrain of the map. Empty (the minimap was removed): nothing to give it.
@export var minimap: Minimap

## The map of this match (set in _enter_tree).
var map: MapRoot
## The map and the mode this world plays, read once from ActiveMatch when it enters the tree; the systems get them from here.
var definition: MapDefinition
var mode: GameMode

var _entered_ms := 0
var _local_wizard: Node3D


func _enter_tree() -> void:
	_entered_ms = Time.get_ticks_msec()
	## RFC-032 032b: the ticks of the match start at 0 on every peer (the client counts its own for the cooldowns).
	MatchClock.begin(get_tree())
	## The one who simulates applies the match setup (level, friendly fire, drop soul, starting souls; RFC-031 031a2/031d)
	## before any child is ready (RFC-024 §5.1). The setup returns a copy when it overrides something (an empty setup returns `rules` itself): never mutate world.rules at runtime.
	if not MpKit.is_networked() or MpKit.is_server():
		rules = SacrificeFlow.setup.apply_to(rules)
	## Every peer seeds the match: online with the seed the server announced (RFC-060 060s), offline with the rules' or a drawn one.
	MatchSeed.begin(rules, ActiveMatch.match_seed())
	definition = ActiveMatch.map()
	mode = ActiveMatch.mode()
	SideRelations.use(definition, mode)
	_attach_map()


## Puts the active map first under `map_parent` (it is ready before the systems that read it) and binds the systems.
func _attach_map() -> void:
	if map_parent == null:
		push_error("Match: map_parent must be set in match.tscn.")
		return
	## One line for the logs and the runs (RFC-049 049a): which map this process loaded, and whether it simulates it.
	print(("mapa %s" if not MpKit.is_networked() or MpKit.is_server() else "en mapa %s") % definition.tag)
	map = map_parent.get_node_or_null(MAP_NODE) as MapRoot
	if map != null and definition.map_scene != null and map.scene_file_path != definition.map_scene.resource_path:
		map_parent.remove_child(map)
		map.free()
		map = null
	if map == null:
		var packed := definition.map_scene
		map = packed.instantiate() as MapRoot if packed != null else null
		if map == null:
			push_error("Match: the map '%s' has no MapRoot; the match cannot start." % definition.tag)
			return
		map.name = MAP_NODE
		map_parent.add_child(map)
		map_parent.move_child(map, 0)
	_bind_map()


## The sockets of the map into the exports of the systems that need its parts.
func _bind_map() -> void:
	if camera == null or selection == null or nav == null or wizard_spawner == null:
		push_error("Match: camera, selection, nav and wizard_spawner must be set in match.tscn.")
		return
	if population == null or graphics_applier == null:
		push_error("Match: population and graphics_applier must be set in match.tscn.")
		return
	var drawn := map.terrain.mesh if map.terrain != null else null
	camera.ground = drawn
	selection.ground = drawn
	nav.terrain = map.terrain
	nav.region = map.nav_region
	wizard_spawner.spawn_points = wizard_spawner.get_path_to(map.starts)
	population.buildings = map.buildings
	population.npcs = map.npcs
	if minimap != null:
		minimap.terrain_bake = map.minimap_bake
	graphics_applier.rig = map.look


func _ready() -> void:
	var map_name := "?"
	if definition:
		map_name = definition.display_name if not definition.display_name.is_empty() else String(definition.tag)
	print("en %s slot %d" % [map_name, MpKit.local_slot()])
	if match_state:
		match_state.result_changed.connect(_on_result_changed)
	%Wizards.child_entered_tree.connect(_on_wizard_entered)
	for wizard in %Wizards.get_children():
		_check_local(wizard)
	print("mundo listo %d ms" % (Time.get_ticks_msec() - _entered_ms))


## Where the shader warm-up starts its walk (WarmCollect): this match's map and every god and wizard a seat can pick (any of them can show up).
func warm_roots() -> Array[Resource]:
	var roots: Array[Resource] = [definition]
	var catalog := GameCatalog.shared()
	roots.append_array(catalog.offered_gods())
	roots.append_array(catalog.offered_wizards())
	return roots


## The wizard of this process's player; null on the dedicated server or before the spawn arrives.
func local_wizard() -> Node3D:
	if _local_wizard and is_instance_valid(_local_wizard):
		return _local_wizard
	return null


func _on_wizard_entered(node: Node) -> void:
	if not node.is_node_ready():
		node.ready.connect(_check_local.bind(node), CONNECT_ONE_SHOT)


func _check_local(node: Node) -> void:
	if not node is WizardBody or not (node as WizardBody).is_local():
		return
	_local_wizard = node as Node3D
	camera.set_follow(_local_wizard)
	local_wizard_changed.emit(_local_wizard)


## The match has a result (the banner shows it): the world no longer takes clicks.
func _on_result_changed() -> void:
	if MpKit.local_slot() <= 0:
		return
	var view := get_node_or_null("%View") as Button
	if view:
		view.disabled = true
