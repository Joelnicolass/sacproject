extends RefCounted

## Case of rules_suite for the land of a match: a forced god wins (each god with a look gets its own look profile), an empty choice draws
## exactly like before for a fixed seed, and the choice travels through MatchSetup, the room options and the ticket.

const SEEDS: Array[int] = [1, 7, 12345, 987654321]


func run(_host: Node) -> Dictionary:
	var failures: PackedStringArray = []
	var catalog := GameCatalog.shared()
	var with_look: Array[StringName] = []
	for type in catalog.gods:
		if type.look != null:
			with_look.append(StringName(type.tag))
	if with_look.size() < 2:
		failures.append("the catalog needs at least two gods with a look")
	for god in with_look:
		for match_seed in SEEDS:
			if BiomeRules.choose(god, match_seed) != god:
				failures.append("forced %s with seed %d must give %s" % [god, match_seed, god])
		if catalog.god(String(god)).look == null:
			failures.append("%s must bring its look profile" % god)
	for match_seed in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = match_seed
		var expected := StringName(catalog.gods[rng.randi_range(0, catalog.gods.size() - 1)].tag)
		if BiomeRules.choose(&"", match_seed) != expected or BiomeRules.pick_god(match_seed) != expected:
			failures.append("empty choice with seed %d must draw %s like before" % [match_seed, expected])
	if BiomeRules.choose(&"nobody", 7) != BiomeRules.pick_god(7):
		failures.append("a god with no look must be drawn")
	_check_setup(failures, with_look)
	_check_ticket(failures, with_look)
	return {"biome": {"ok": failures.is_empty(), "failures": failures}}


func catalog_god(tag: StringName) -> GodType:
	return GameCatalog.shared().god(String(tag))


func _check_setup(failures: PackedStringArray, with_look: Array[StringName]) -> void:
	if with_look.is_empty():
		return
	var rules := MatchRules.new()
	var setup := MatchSetup.new()
	if not setup.is_empty() or setup.apply_to(rules) != rules:
		failures.append("an empty setup must return the very same rules")
	var god: GodType = catalog_god(with_look[0])
	setup.biome = god
	if setup.is_empty():
		failures.append("a setup with a biome is not empty")
	var applied := setup.apply_to(rules) as MatchRules
	if applied == rules or applied.biome_god != with_look[0] or rules.biome_god != &"":
		failures.append("apply_to must copy the rules with the biome and leave the original alone")
	var merged := MatchSetup.new().overlaid_by(setup)
	if merged.biome != god or setup.copy().biome != god:
		failures.append("overlaid_by and copy must carry the biome")
	var empty_over := setup.overlaid_by(MatchSetup.new())
	if empty_over.biome != god:
		failures.append("an empty overlay must keep the biome")


func _check_ticket(failures: PackedStringArray, with_look: Array[StringName]) -> void:
	if with_look.is_empty():
		return
	var room_rules := SacrificeRoomRules.new()
	var options := {"biome": String(with_look[0])}
	if not room_rules.are_options_valid(options):
		failures.append("a room option with a god's land must be valid")
	if room_rules.are_options_valid({"biome": "nobody"}) or room_rules.are_options_valid({"biome": 3}):
		failures.append("a room option with an unknown or non-text land must be invalid")
	var ticket := room_rules.build_ticket([], options)
	var setup := MatchTicketGlue.setup_from_ticket(ticket)
	if setup.biome != catalog_god(with_look[0]):
		failures.append("the ticket must bring the land to the match setup (got '%s')" % setup.biome)
	if MatchTicketGlue.setup_from_ticket(room_rules.build_ticket([], {})).biome != null:
		failures.append("a ticket without a land must leave it drawn")
	room_rules.free()
