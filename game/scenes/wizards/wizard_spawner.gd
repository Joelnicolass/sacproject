extends MpSlotSpawner

## One wizard_body.tscn per occupied player slot (the dedicated server is not a player).
## Each wizard appears at spawn_transform() of the PlayerStart with its slot number (the WizardSpot marker of that
## start), among the children of spawn_points (MapProps/Starts).


## RFC-068: `despawn_on_leave` is off in match.tscn: a player who drops may come back to the same slot within the grace of the
## door of the match (MpMatchGate), on every networked path. His wizard, creatures and altar stay in the world, the wizard standing
## still; past the grace the slot loses (SeatPresence).
func _ready() -> void:
	super._ready()
	if not despawn_on_leave and MpKit.is_networked() and MpKit.is_server():
		MpKit.peer_left.connect(_on_slot_peer_away)
	if MpKit.is_networked() and MpKit.is_server():
		_spawn_ready_peers()


func _exit_tree() -> void:
	if MpKit.peer_left.is_connected(_on_slot_peer_away):
		MpKit.peer_left.disconnect(_on_slot_peer_away)
	super._exit_tree()


func _on_slot_peer_away(_peer_id: int, slot: int) -> void:
	var wizard := pawn_for(slot) as WizardBody
	if is_instance_valid(wizard):
		wizard.stand_still()


func _spawn_ready_peers() -> void:
	for peer in multiplayer.get_peers():
		if MpKit.is_peer_world_ready(peer):
			spawn_slot(MpKit.slot_for_peer(peer))


func _place(pawn: Node, slot: int) -> void:
	pawn.set("owner_slot", slot)
	## RFC-049 049b: a wizard sat in this seat; only the seated sides count for the victory (human or AI, on the authority).
	if not MpKit.is_networked() or MpKit.is_server():
		var match_state := get_tree().get_first_node_in_group(&"match_state") as MatchState
		if match_state != null:
			match_state.mark_seated(slot)
	var rules: Variant = owner.get("rules") if owner else null
	if rules is MatchRules:
		var match_rules := rules as MatchRules
		var level := _level(match_rules)
		pawn.set("level", level)
		if match_rules.wizard_level_stats:
			pawn.set("level_health_bonus", match_rules.health_per_level * level)
			pawn.set("level_mana_bonus", match_rules.mana_per_level * level)
		for component in ["SoulPurse", "ManaPool", "Health", "Spellbook", "Caster", "GhostForm"]:
			var node := pawn.get_node_or_null(component)
			if node:
				node.set("rules", rules)
	var start := _start_for(slot)
	if start == null or not pawn is Node3D:
		return
	var body := pawn as Node3D
	var spot := start.spawn_transform()
	body.position = (_root as Node3D).to_local(spot.origin)
	body.rotation.y = spot.basis.get_euler().y


## RFC-030 030d (F115): the level of this match. The level chosen in the boot or with --level is already in the world's
## rules (MatchSetup.apply_to in HighNoon, RFC-031 031a2).
func _level(match_rules: MatchRules) -> int:
	return match_rules.wizard_level


## The start with that slot number. With more players than starts they share, in order.
func _start_for(slot: int) -> PlayerStart:
	var points := _spawn_points_node()
	if points == null:
		return null
	var starts: Array[PlayerStart] = []
	for child in points.get_children():
		var start := child as PlayerStart
		if start == null:
			continue
		if start.slot == slot:
			return start
		starts.append(start)
	if starts.is_empty():
		return null
	return starts[(slot - 1) % starts.size()]
