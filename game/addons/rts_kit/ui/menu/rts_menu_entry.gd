@tool
class_name RtsMenuEntry
extends Resource

## One choice any command UI offers (a command card button, a radial menu slot, a game's own list):
## an order of the command catalog, a formation, or something of the game's. The UI only shows it and
## says it was chosen; RtsOrderInput.run_entry turns it into an order, the same way for every UI.
##
## COMMAND: `command` (an RtsCommandType id). Run at a screen point (a menu opened there): the order of
## that point, on the body there or the ground. Run with no point (a button): a command that aims is
## armed for the next left click, one that does not (retreat) happens at once.
## FORMATION: `formation`. At a point: the right click of that point in that formation. With no point:
## the selection keeps it.
## CUSTOM: the game's (RtsOrderInput.custom_entry).

enum Kind { COMMAND, FORMATION, CUSTOM }

@export var id: StringName = &""
@export var kind := Kind.COMMAND
## COMMAND: the command id.
@export var command: StringName = &""
## FORMATION: the formation.
@export var formation: RtsFormation
## The words shown (translated with `tr`); empty = the command's or formation's name.
@export var label := ""
@export var icon: Texture2D
## The InputMap action that does the same thing (a button shows its key).
@export var hotkey_action: StringName = &""


## An entry for command `type`.
static func for_command(type: RtsCommandType, action := &"") -> RtsMenuEntry:
	var entry := RtsMenuEntry.new()
	entry.id = type.id
	entry.kind = Kind.COMMAND
	entry.command = type.id
	entry.label = type.display_name
	entry.icon = type.icon
	entry.hotkey_action = action
	return entry


## An entry for `value`.
static func for_formation(value: RtsFormation, action := &"") -> RtsMenuEntry:
	var entry := RtsMenuEntry.new()
	entry.id = value.id
	entry.kind = Kind.FORMATION
	entry.formation = value
	entry.label = value.display_name
	entry.icon = value.icon
	entry.hotkey_action = action
	return entry


## Entries for `commands` (the ids listed, in that order; empty = every command of the catalog)
## followed by every formation of `formations`. `actions` maps a command id to its hotkey action;
## formation N gets `formation_action_prefix` + N.
static func from_catalogs(
	command_catalog: RtsCommandCatalog,
	formation_catalog: RtsFormationCatalog,
	commands: Array[StringName] = [],
	actions: Dictionary = {},
	formation_action_prefix := "rts_formation_"
) -> Array[RtsMenuEntry]:
	var result: Array[RtsMenuEntry] = []
	if command_catalog:
		var ids: Array[StringName] = commands
		if ids.is_empty():
			for type in command_catalog.commands:
				if type:
					ids.append(type.id)
		for id in ids:
			var type := command_catalog.find(id)
			if type:
				result.append(for_command(type, actions.get(id, &"")))
	if formation_catalog:
		for i in formation_catalog.formations.size():
			var value := formation_catalog.formations[i]
			if value:
				result.append(for_formation(value, StringName(formation_action_prefix + str(i + 1))))
	return result


func display_label() -> String:
	if not label.is_empty():
		return label
	if formation:
		return formation.display_name
	return String(command if command != &"" else id)


func display_icon() -> Texture2D:
	if icon != null:
		return icon
	return formation.icon if formation else null
