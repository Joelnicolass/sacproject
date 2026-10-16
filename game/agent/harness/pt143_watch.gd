extends Node

## Read-only observer for the F143 check (RFC-031 031d, Options → Jugabilidad). Never changes a preference or a rule.
## Tolerates scene == null.
##   state()   one line: GameplayPrefs (shared instance), `[partida]` of the settings file of this run (UserSettings.path(); none when sandboxed), the Jugabilidad tab's controls
##             (if any), MatchState's rules (if any) and the soul purse of each wizard.
## Props for wait_until: wizards (wizards with a purse in the tree).

const PREFS := "res://data/ui/gameplay_prefs.tres"


var wizards := 0


func state() -> String:
	var prefs := load(PREFS) as GameplayPrefs
	var line := "pt143 prefs ff=%s drop=%s souls=%d" % [prefs.friendly_fire(), prefs.drop_soul(), prefs.starting_souls()]
	line += " file=%s" % _file_section()
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		print(line + " scene=null")
		return line
	var tab := tree.root.find_child("GameplayTab", true, false)
	if tab != null:
		var ff := tab.get_node_or_null("%FriendlyFire") as BaseButton
		var drop := tab.get_node_or_null("%DropSoul") as BaseButton
		var souls := tab.get_node_or_null("%StartingSouls") as SpinBox
		var note := tab.get_node_or_null("%RulesNote") as Label
		if ff and drop and souls and note:
			line += " tab visible=%s ff=%s drop=%s souls=%d disabled=%s editable=%s note=%s" % [
				(tab as Control).is_visible_in_tree(), ff.button_pressed, drop.button_pressed, int(souls.value),
				ff.disabled and drop.disabled, souls.editable, note.is_visible_in_tree(),
			]
	var match_state := tree.get_first_node_in_group(&"match_state") as MatchState
	if match_state != null:
		line += " state ff=%s drop=%s souls=%d" % [match_state.friendly_fire, match_state.drop_soul, match_state.starting_souls]
	var purses := []
	for wizard in tree.get_nodes_in_group("wizard"):
		var purse := wizard.get_node_or_null("SoulPurse")
		if purse != null:
			purses.append("%s:%s" % [wizard.get("owner_slot"), purse.get("count")])
	wizards = purses.size()
	purses.sort()
	line += " purses=%s" % ",".join(purses)
	print(line)
	return line


func _file_section() -> String:
	if UserSettings.sandboxed():
		return "sandbox"
	var config := ConfigFile.new()
	if config.load(UserSettings.path()) != OK:
		return "none"
	if not config.has_section("partida"):
		return "no-partida"
	var parts := []
	for key in config.get_section_keys("partida"):
		parts.append("%s=%s" % [key, config.get_value("partida", key)])
	return "{%s}" % ";".join(parts)
