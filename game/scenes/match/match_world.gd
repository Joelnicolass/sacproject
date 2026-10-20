class_name MatchWorld
extends Node3D

signal local_wizard_changed(wizard: Node3D)

## RFC-044: the match is map-agnostic. The map is the child `Map` (a MapRoot): the one the scene already holds
## (scenes/match/high_noon.tscn) or, when there is none or `--map=<tag>` asks for another, the scene of the active
## MapDefinition. The systems below are bound to its sockets before any of them is ready.
const MAP_NODE := "Map"

@export var rules: MatchRules

## The map of this match (set in _enter_tree).
var map: MapRoot

var _entered_ms := 0
var _local_wizard: Node3D


func _enter_tree() -> void:
	_entered_ms = Time.get_ticks_msec()
	## RFC-032 032b: the ticks of the match start at 0 on every peer (the client counts its own for the cooldowns).
	MatchClock.begin(get_tree())
	## The one who simulates applies the match setup (level, friendly fire, drop soul, starting souls; RFC-031 031a2/031d) and draws (or takes) the match
	## seed before any child is ready (RFC-024 §5.1). The setup returns a copy when it overrides something (an empty setup returns `rules` itself): never mutate world.rules at runtime.
	if not MpKit.is_networked() or MpKit.is_server():
		rules = SacrificeFlow.setup.apply_to(rules)
		MatchSeed.begin(rules)
	_attach_map()


## Puts the active map first among the children (it is ready before the systems that read it) and binds the systems.
func _attach_map() -> void:
	var definition := MapCatalog.active()
	## One line for the logs and the runs (RFC-049 049a): which map this process loaded, and whether it simulates it.
	print(("mapa %s" if not MpKit.is_networked() or MpKit.is_server() else "en mapa %s") % definition.tag)
	map = get_node_or_null(MAP_NODE) as MapRoot
	if map != null and not definition.map_scene_path.is_empty() and map.scene_file_path != definition.map_scene_path:
		remove_child(map)
		map.free()
		map = null
	if map == null:
		var packed := definition.load_scene()
		map = packed.instantiate() as MapRoot if packed != null else null
		if map == null:
			push_error("Match: the map '%s' has no MapRoot; the match cannot start." % definition.tag)
			return
		map.name = MAP_NODE
		add_child(map)
		move_child(map, 0)
	_bind_map()


## The sockets of the map into the exports of the systems that need its parts.
func _bind_map() -> void:
	%Camera.set("ground", map.terrain)
	%Selection.set("ground", map.terrain)
	%Nav.set("terrain", map.terrain)
	%Nav.set("region", map.nav_region)
	var spawner := $WizardSpawner as MultiplayerSpawner
	spawner.set("spawn_points", spawner.get_path_to(map.starts))
	%Population.set("buildings_root", map.buildings_root)
	%Population.set("npc_spawns_root", map.npc_spawns_root)
	%Minimap.set("terrain_bake", map.minimap_bake)
	$GraphicsApplier.set("rig", map.look)


func _ready() -> void:
	var definition := MapCatalog.active()
	var map_name := "?"
	if definition:
		map_name = definition.display_name if not definition.display_name.is_empty() else String(definition.tag)
	print("en %s slot %d" % [map_name, MpKit.local_slot()])
	var match_state := get_node_or_null("%Match") as MatchState
	if match_state:
		match_state.result_changed.connect(_on_result_changed)
	%Wizards.child_entered_tree.connect(_on_wizard_entered)
	for wizard in %Wizards.get_children():
		_check_local(wizard)
	print("mundo listo %d ms" % (Time.get_ticks_msec() - _entered_ms))


## The wizard of MpKit.local_slot(); null on the dedicated server or before the spawn arrives.
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
	%Camera.set_follow(_local_wizard)
	%WizardHud.bind(_local_wizard)
	%SpellBook.bind(_local_wizard)
	_place_creature.call_deferred()
	local_wizard_changed.emit(_local_wizard)


## The match has a result (the banner shows it): the world no longer takes clicks.
func _on_result_changed() -> void:
	if MpKit.local_slot() <= 0:
		return
	var view := get_node_or_null("%View") as Button
	if view:
		view.disabled = true


func _place_creature() -> void:
	var wizard := local_wizard()
	if wizard == null:
		return
	for _attempt in 3:
		await get_tree().physics_frame
	var creature: Node3D = %Creature
	creature.position = wizard.position + Vector3(6, 0, 0)
	creature.visible = false
