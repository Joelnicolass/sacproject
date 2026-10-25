class_name MatchWire
extends RefCounted

## The one place where the product turns a Resource into the text the network carries, and back: a pick, the picks by slot, a
## god of a bot seat. Screens and gameplay hold `WizardPick` / `GodType` / `WizardType`; only this file (and the catalogs) knows
## that the wire says `cwa1` and `persephone`. The wire is the same text as always: {"wizard", "model", "god"}, in that order.
## It does not talk to the network and it does not decide who may pick: SacrificeFlow and SacrificeRoomRules do.


## {"wizard": id, "model": model, "god": id} of a complete pick. The model is derived from the wizard (it stays on the wire
## until the body becomes a scene of its own).
static func encode_pick(pick: WizardPick) -> Dictionary:
	return {"wizard": pick.wizard.id(), "model": pick.wizard.model, "god": pick.god.id()}


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
