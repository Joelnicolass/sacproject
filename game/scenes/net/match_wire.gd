class_name MatchWire
extends RefCounted

## The one place where the product turns a Resource into the text the network carries, and back: a pick, the picks by slot, a
## god of a bot seat, the map and the mode of the match and the options of a room. Screens and gameplay hold `WizardPick` /
## `GodType` / `MapDefinition` / `GameMode`; only this file (and the catalogs) knows that the wire says `cwa1`, `persephone`,
## `high_noon` and `1v1`. The wire is the same text as always: a pick is {"wizard", "model", "god"}, in that order.
## It does not talk to the network and it does not decide who may pick: SacrificeFlow and SacrificeRoomRules do.


## {"wizard": id, "model": model, "god": id} of a complete pick. The model is derived from the wizard (it stays on the wire
## until the body becomes a scene of its own).
static func encode_pick(pick: WizardPick) -> Dictionary:
	return {"wizard": pick.wizard.id(), "model": pick.wizard.model_id(), "god": pick.god.id()}


## The id of a bot's god; empty (no god) = drawn when the match starts.
static func encode_god(god: GodType) -> String:
	return god.id() if god != null else ""


## The pick a wire Dictionary names, or null when it is not one (not a Dictionary, an id the catalog does not have, or, with
## `offered_only`, a wizard or god the lobby does not offer). The `model` of the wire is ignored: the wizard's own is the truth.
static func decode_pick(raw: Variant, offered_only := false) -> WizardPick:
	if not raw is Dictionary:
		return null
	var wizard: WizardType = decode_wizard(str(raw.get("wizard", "")), offered_only)
	var god: GodType = decode_god(str(raw.get("god", "")), offered_only)
	if wizard == null or god == null:
		return null
	var pick: WizardPick = WizardPick.new()
	pick.wizard = wizard
	pick.god = god
	return pick


## The same pick checked and written again, or {} when the wire Dictionary is not a valid offered pick.
static func clean_pick(raw: Variant) -> Dictionary:
	var pick: WizardPick = decode_pick(raw, true)
	return encode_pick(pick) if pick != null else {}


## {slot: pick Dictionary} as the `slot_picks` channel carries it.
static func encode_picks(picks: Dictionary[int, WizardPick]) -> Dictionary:
	var out := {}
	for slot in picks.keys():
		out[slot] = encode_pick(picks[slot])
	return out


## The picks of a `slot_picks` message; a slot whose pick this client cannot read is left out (and logged).
static func decode_picks(raw: Variant) -> Dictionary[int, WizardPick]:
	var out: Dictionary[int, WizardPick] = {}
	if not raw is Dictionary:
		return out
	for slot in raw.keys():
		var pick: WizardPick = decode_pick(raw[slot])
		if pick == null:
			push_error("MatchWire: the pick of slot %s names a wizard or a god this client does not have." % str(slot))
			continue
		out[int(slot)] = pick
	return out


## The god with that id, or null (empty, unknown or, with `offered_only`, not offered).
static func decode_god(id: String, offered_only := false) -> GodType:
	var god: GodType = GameCatalog.shared().god(id) if not id.is_empty() else null
	return god if god != null and (god.offered or not offered_only) else null


## The wizard with that id, or null (empty, unknown or, with `offered_only`, not offered).
static func decode_wizard(id: String, offered_only := false) -> WizardType:
	var wizard: WizardType = GameCatalog.shared().wizard(id) if not id.is_empty() else null
	return wizard if wizard != null and (wizard.offered or not offered_only) else null


## The map with that id, or null (empty or unknown).
static func decode_map(id: String) -> MapDefinition:
	return MapCatalog.shared().find(StringName(id)) if not id.is_empty() else null


## The mode with that id, or null (empty or unknown).
static func decode_mode(id: String) -> GameMode:
	return GameModeCatalog.shared().find(StringName(id)) if not id.is_empty() else null


## {"map": id, "mode": id} of what this process plays: the part of the flow snapshot a late joiner needs before the world loads.
static func encode_choice() -> Dictionary:
	return {"map": String(ActiveMatch.map_tag()), "mode": String(ActiveMatch.mode_tag())}


## A client takes the map and the mode the server announced. One this client does not have is an error and the other one is
## kept (as is anything the message leaves out). By tag only: loading the map's definition here held the admission for seconds.
static func decode_choice(data: Dictionary) -> void:
	var chosen_mode: StringName = ActiveMatch.mode_tag()
	var chosen_map: StringName = ActiveMatch.map_tag()
	var mode_id := str(data.get("mode", ""))
	if not mode_id.is_empty():
		if decode_mode(mode_id) == null:
			push_error("MatchWire: el servidor mandó el modo '%s' y este cliente no lo tiene." % mode_id)
		else:
			chosen_mode = StringName(mode_id)
			print("modo de la partida %s (del servidor)" % mode_id)
	var map_id := str(data.get("map", ""))
	if not map_id.is_empty():
		if not MapCatalog.shared().has(StringName(map_id)):
			push_error("MatchWire: el servidor mandó el mapa '%s' y este cliente no lo tiene." % map_id)
		else:
			chosen_map = StringName(map_id)
			print("mapa de la partida %s (del servidor)" % map_id)
	ActiveMatch.choose_ids(chosen_map, chosen_mode)


## The `options` of a room made from what a form chose: `mode`, `world`, `biome` (ids) and `level` (> 0), each only when set.
static func options_of(setup: MatchSetup) -> Dictionary:
	var out := {}
	if setup.mode != null:
		out["mode"] = String(setup.mode.tag)
	if setup.map != null:
		out["world"] = String(setup.map.tag)
	if setup.biome != null:
		out["biome"] = setup.biome.id()
	if setup.level > 0:
		out["level"] = setup.level
	return out


## The mode the options of a room name (the default one if they name none); null if it is one this client does not have.
static func mode_in(options: Dictionary) -> GameMode:
	var id := str(options.get("mode", ""))
	return decode_mode(id if not id.is_empty() else String(GameModeCatalog.DEFAULT_TAG))


## The map the options of a room name (the default one if they name none); null if it is one this client does not have.
static func map_in(options: Dictionary) -> MapDefinition:
	var id := str(options.get("world", ""))
	return decode_map(id if not id.is_empty() else String(MapCatalog.DEFAULT_TAG))


## The god whose land the options of a room name; null = drawn.
static func land_in(options: Dictionary) -> GodType:
	return decode_god(str(options.get("biome", "")))
