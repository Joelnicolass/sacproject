@tool
class_name RtsCueSet
extends Resource

## What the command cursor shows instead of words: the picture that goes with an armed order, the one
## that flashes on a refusal, which keys mean "refused", the words of each refusal, and the cursor
## picture that goes with what lies under the pointer. Every picture is a Texture2D assigned in the
## inspector. It does not choose what to show: RtsCommandCue, RtsCursorSkin and RtsRefusalReason read
## it. Another look is another .tres.

## Armed kind (&"attack", &"guard", &"move", or a game's) -> the picture shown below the pointer.
@export var aim_icons: Dictionary[StringName, Texture2D] = {}
## The picture that flashes on a refusal.
@export var refused_icon: Texture2D
## Refusal key (RtsRefusal.NO_GROUND, a game's &"no_mana") -> cue. A key mapped to &"" is a known
## reason that flashes nothing.
@export var refusals: Dictionary[StringName, StringName] = {
	RtsRefusal.NO_GROUND: &"refused",
	RtsRefusal.NOBODY: &"refused",
	RtsRefusal.NO_ANCHOR: &"refused",
	RtsRefusal.NO_TARGET: &"refused",
	RtsRefusal.NOT_TAKEN: &"refused",
}
## Refusal key -> the words the player reads (translated with `tr`). No entry: the key itself goes
## through `tr`, so a translation table can hold them instead.
@export var reason_texts: Dictionary[StringName, String] = {
	RtsRefusal.NO_GROUND: "No ground there",
	RtsRefusal.NOBODY: "Nothing selected",
	RtsRefusal.NO_ANCHOR: "Nowhere to retreat to",
	RtsRefusal.NO_TARGET: "Nothing to aim at there",
	RtsRefusal.NOT_TAKEN: "Nobody can do that",
}
## What lies under the pointer (RtsTargetProbe class: `none`, `ground`, `own_unit`, `enemy_unit`…) ->
## cursor picture while nothing is armed.
@export var free_cursors: Dictionary[StringName, Texture2D] = {}
## The same while something waits for its target.
@export var target_cursors: Dictionary[StringName, Texture2D] = {}
## The cursor while the armed thing would be refused at the pointer (RtsCommandState.aim_status).
@export var blocked_cursor: Texture2D
## The cursor over the HUD and at rest.
@export var hud_cursor: Texture2D


## True when `text` is a refusal key this set knows (with or without a cue).
func has_reason(text: String) -> bool:
	return refusals.has(StringName(text))


## The cue a message means: &"refused" or &"" (an unknown message has no cue).
func cue_for(text: String) -> StringName:
	return refusals.get(StringName(text), &"")


## The words of a refusal key, translated.
func reason_text(key: StringName) -> String:
	return tr(reason_texts.get(key, String(key)))


## The aim picture for an armed kind, or null.
func aim_icon(kind: StringName) -> Texture2D:
	return aim_icons.get(kind)


## The cursor picture for a target class; `armed` = something waits for its target; `blocked` = it
## would be refused there.
func cursor_for(target_class: StringName, armed: bool, blocked := false) -> Texture2D:
	if armed and blocked and blocked_cursor != null:
		return blocked_cursor
	var table := target_cursors if armed else free_cursors
	return table.get(target_class, hud_cursor)
