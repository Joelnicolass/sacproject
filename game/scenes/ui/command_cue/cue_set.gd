class_name CueSet
extends Resource

## What the command cursor shows instead of words: the picture that goes with an armed order, the one that flashes on a refusal,
## which words mean «refused» and the cursor picture that goes with what lies under the pointer. Every picture is a Texture2D
## assigned in the inspector (data/ui/command_cues.tres). It does not choose by itself what to show: CommandCue and CursorSkin read it.
## Another variant is another .tres.

## Armed order (`attack`, `advance`, `guard`, `guard_area`, `move`, `retreat`) -> the picture shown below the pointer.
@export var aim_icons: Dictionary[StringName, Texture2D] = {}
## The picture that flashes on a refusal.
@export var refused_icon: Texture2D
## Refusal key (`Refusal`, a StringName like `&"no_mana"`) -> cue. A key mapped to &"" is a known reason that
## flashes nothing. Never the words on screen: those are translated.
@export var refusals: Dictionary = {}
## What lies under the pointer (`none`, `ground`, `own_unit`, `enemy_building`…) -> cursor picture while nothing is armed.
@export var free_cursors: Dictionary[StringName, Texture2D] = {}
## The same while an icon waits for its target.
@export var target_cursors: Dictionary[StringName, Texture2D] = {}
## The cursor while the armed icon would be refused where the pointer is (CommandLog.aim_status), whatever lies there.
@export var blocked_cursor: Texture2D
## Cursor for the pointer over the HUD (not the world) and the one in the pointer's rest state.
@export var hud_cursor: Texture2D


## True when `text` is a refusal key this set knows (with or without a cue).
func has_reason(text: String) -> bool:
	return refusals.has(StringName(text))


## The cue a message means: `refused` or &"" (an unknown message has no cue).
func cue_for(text: String) -> StringName:
	return StringName(refusals.get(StringName(text), &""))


## Aim picture for an order kind, or null.
func aim_icon(kind: String) -> Texture2D:
	return aim_icons.get(StringName(kind))


## Cursor picture for a target class; `armed` = an icon waits for its target; `blocked` = it would be refused there.
func cursor_for(target_class: StringName, armed: bool, blocked := false) -> Texture2D:
	if armed and blocked and blocked_cursor != null:
		return blocked_cursor
	var table := target_cursors if armed else free_cursors
	return table.get(target_class, hud_cursor)
