extends MpSlotSpawner

## One wizard_body.tscn per occupied player slot (the dedicated server is not a player).
## Each wizard appears at spawn_transform() of the PlayerStart with its slot number (the WizardSpot marker of that
## start), among the children of spawn_points (MapProps/Starts).
## It gives every wizard its seat's pick (`WizardBody.seat_pick`) on every peer: before add_child where it spawns them,
## when the spawn arrives on a client, and again whenever the picks change.


## RFC-068: `despawn_on_leave` is off in match.tscn: a player who drops may come back to the same slot within the grace of the
## door of the match (MpMatchGate), on every networked path. His wizard, creatures and altar stay in the world, the wizard standing
## still; past the grace the slot loses (SeatPresence).
func _ready() -> void:
	super._ready()
	var gate := Mp.gate()
	if not despawn_on_leave and gate != null:
		gate.seat_away.connect(_on_seat_away)
	spawned.connect(_on_spawned)
	SacrificeFlow.slot_picks_changed.connect(_give_picks)


func _exit_tree() -> void:
	var gate := Mp.gate()
	if gate != null and gate.seat_away.is_connected(_on_seat_away):
		gate.seat_away.disconnect(_on_seat_away)
	if SacrificeFlow.slot_picks_changed.is_connected(_give_picks):
		SacrificeFlow.slot_picks_changed.disconnect(_give_picks)
	super._exit_tree()


func _on_seat_away(slot: int) -> void:
	var wizard := pawn_for(slot) as WizardBody
	if is_instance_valid(wizard):
		wizard.stand_still()


## A client: the wizard the server spawned arrived (its `owner_slot` came with it).
func _on_spawned(node: Node) -> void:
	var wizard := node as WizardBody
	if wizard != null:
		wizard.seat_pick = SacrificeFlow.pick_for(wizard.owner_slot)


## The picks changed (a late pick, a seat that changed its mind): every wizard wears its seat's pick again.
func _give_picks() -> void:
	if _root == null:
		return
	for child in _root.get_children():
		var wizard := child as WizardBody
		if wizard != null:
			wizard.seat_pick = SacrificeFlow.pick_for(wizard.owner_slot)


func _place(pawn: Node, slot: int) -> void:
	## MatchState seats the slot when the wizard enters `Wizards` (RFC-049 049b), so `owner_slot` goes before add_child.
	pawn.set("owner_slot", slot)
	var wizard := pawn as WizardBody
	if wizard != null:
		wizard.seat_pick = SacrificeFlow.pick_for(slot)
	## An AI seat has no keys to predict from: it moves on the server (WizardBody steps Drive itself) and owns no MpInput frames.
	var net := MpActor.of(pawn)
	if net != null and SacrificeFlow.board.is_ai(slot):
		net.predict = false
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
## rules (MatchSetup.apply_to in MatchWorld, RFC-031 031a2).
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
