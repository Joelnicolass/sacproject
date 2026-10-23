class_name BiomeRules
extends RefCounted

## Which god's land a match gets. The match seed picks it, so the server and every client agree: the
## dedicated server only needs the name (it never loads the land's look), and a headless test gets the same one.

## The god a match seed picks: one draw from a generator seeded with it, over the gods in catalog order.
static func pick_god(match_seed: int) -> StringName:
	var gods := GameCatalog.shared().gods
	if gods.is_empty():
		return &""
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed
	return StringName(gods[rng.randi_range(0, gods.size() - 1)].tag)


## The god a match plays: `forced` when it has a look, otherwise the one the seed picks.
static func choose(forced: StringName, match_seed: int) -> StringName:
	return forced if has_look(forced) else pick_god(match_seed)


## A god of the catalog that brings a look to the match.
static func has_look(god: StringName) -> bool:
	var type := GameCatalog.shared().god(String(god))
	return type != null and type.look != null
