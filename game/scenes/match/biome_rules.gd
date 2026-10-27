class_name BiomeRules
extends RefCounted

## Which god's land a match gets. The match seed picks it, so the server and every client agree: the
## dedicated server only needs the god (it never shows the land's look), and a headless test gets the same one.
## It does not apply the look (MatchBiome) and does not send it (BiomeLink).

## The god a match seed picks: one draw from a generator seeded with it, over `gods` in their order (the catalog's). A god
## without a look can come out: the match then has no land. Null when `gods` is empty.
static func pick_god(match_seed: int, gods: Array[GodType]) -> GodType:
	if gods.is_empty():
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed
	return gods[rng.randi_range(0, gods.size() - 1)]


## The god a match plays: `forced` when it brings a look, otherwise the one the seed picks.
static func choose(forced: GodType, match_seed: int, gods: Array[GodType]) -> GodType:
	return forced if forced != null and forced.look != null else pick_god(match_seed, gods)
