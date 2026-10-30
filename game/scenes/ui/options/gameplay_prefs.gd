@tool
class_name GameplayPrefs
extends Resource

## The player's choice for the matches the player creates (solo, «Contra la IA»), a local preference
## and never the rule of a match in course (that is MatchState, decided by whoever created the
## match).
## - Friendly fire, dropping souls with P and the starting souls. The defaults are the ones of
##   `rules` (scenes/match/match_rules.tres), which this resource only reads.
## - It lives in `user://settings.cfg` `[partida]` through UserSettings.
## - to_setup sets only what the player chose explicitly (a key in the file, or touched in this
##   run); the rest stays -1, so a flag of the process, or else the rules, decides it: explicit
##   choice > flag > rules.
## - Under AgentKit UserSettings is a sandbox: a playtest starts from the defaults and never writes
##   the player's file.
## - Only the boot reads it (to_setup). The dedicated server and the benches never go through the
##   boot, so they keep the rules and the flags of their process (LaunchFlags).
## Like GraphicsPrefs, every node must share the instance at `SHARED_PATH`; the values are runtime
## state of that instance and the exported fields are never written. Changes emit `changed`.

const SHARED_PATH := "res://scenes/ui/gameplay_prefs.tres"
const SECTION := "partida"

## Where the defaults come from (the product's round rules). Read only.
@export var rules: MatchRules
## Range of the starting souls the menu offers.
@export_range(0, 200) var min_starting_souls := 1
@export_range(0, 200) var max_starting_souls := 30

var _loaded := false
var _friendly_fire := true
var _drop_soul := true
var _starting_souls := 12
## Keys the player chose explicitly (in the file or set in this run).
var _chosen: Dictionary = {}


func friendly_fire() -> bool:
	_ensure_loaded()
	return _friendly_fire


func drop_soul() -> bool:
	_ensure_loaded()
	return _drop_soul


func starting_souls() -> int:
	_ensure_loaded()
	return _starting_souls


func set_friendly_fire(on: bool) -> void:
	if on == friendly_fire():
		return
	_friendly_fire = on
	_chosen["friendly_fire"] = true
	_commit()


func set_drop_soul(on: bool) -> void:
	if on == drop_soul():
		return
	_drop_soul = on
	_chosen["drop_soul"] = true
	_commit()


func set_starting_souls(value: int) -> void:
	var next := clampi(value, min_starting_souls, max_starting_souls)
	if next == starting_souls():
		return
	_starting_souls = next
	_chosen["starting_souls"] = true
	_commit()


## The setup of a match the player creates: `level` (1-9; 0 = the rules' wizard_level) and, of these
## three, only the ones the player chose explicitly (-1 the others: the flag or the rules decide).
func to_setup(level := 0) -> MatchSetup:
	_ensure_loaded()
	var setup := MatchSetup.new()
	setup.level = level if level >= 1 and level <= 9 else 0
	if _chosen.has("friendly_fire"):
		setup.friendly_fire = 1 if _friendly_fire else 0
	if _chosen.has("drop_soul"):
		setup.drop_soul = 1 if _drop_soul else 0
	if _chosen.has("starting_souls"):
		setup.starting_souls = _starting_souls
	return setup


func _commit() -> void:
	if not Engine.is_editor_hint():
		var values := {
			"friendly_fire": _friendly_fire,
			"drop_soul": _drop_soul,
			"starting_souls": _starting_souls
		}
		var chosen := {}
		for key in values:
			if _chosen.has(key):
				chosen[key] = values[key]
		UserSettings.write_values(SECTION, chosen)
	emit_changed()


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var defaults := rules if rules else MatchRules.new()
	_friendly_fire = defaults.friendly_fire
	_drop_soul = defaults.enable_drop_soul
	_starting_souls = clampi(defaults.starting_souls, min_starting_souls, max_starting_souls)
	if Engine.is_editor_hint():
		return
	_friendly_fire = _read_bool("friendly_fire", _friendly_fire)
	_drop_soul = _read_bool("drop_soul", _drop_soul)
	var souls: Variant = UserSettings.read_value(SECTION, "starting_souls", null)
	if typeof(souls) in [TYPE_INT, TYPE_FLOAT]:
		_starting_souls = clampi(int(souls), min_starting_souls, max_starting_souls)
		_chosen["starting_souls"] = true


func _read_bool(key: String, fallback: bool) -> bool:
	var value: Variant = UserSettings.read_value(SECTION, key, null)
	if typeof(value) != TYPE_BOOL:
		return fallback
	_chosen[key] = true
	return value
