class_name CueSet
extends Resource

## What the command cursor shows instead of words (RFC-025c): which icon goes with an armed order,
## which words mean «refused» and which cursor goes with what lies under the pointer. Only tags and
## names of assets/original/ui/{icons,xmenu,cursors}; no image of the original ships here.
## Another variant is another .tres.

## Armed order -> icon tag. `attack`/`advance` = Matt, `guard`/`guard_area` = Mgua, `move` = Mgot
## (icon.FLDR), `retreat` = the XMNU zwp1 (xmenu.wad). sacobject.d SacCursor, xmnu.d XmnuTag.
@export var aim_icons: Dictionary = {}
## The icon that flashes on a refusal (sacCursor.invalidTargetIconTexture).
@export var refused_icon := ""
## Words the server or the click handler answer with when something is refused -> cue. The same
## strings as the constants in SpellAction, Caster, ActiveAbility and MatchCommand.
@export var refusals: Dictionary = {}
## What lies under the pointer -> cursor while nothing is armed (state.d cursor(), showIcon=false).
@export var free_cursors: Dictionary = {}
## The same while an icon waits for its target (state.d cursor(), showIcon=true).
@export var target_cursors: Dictionary = {}
## Cursor for the pointer over the HUD (not the world) and the one in the pointer's rest state.
@export var hud_cursor := ""


## The cue a message means: `refused` or &"" (unknown words only reach CommandLog.text).
func cue_for(text: String) -> StringName:
	return StringName(refusals.get(text, &""))


## Aim icon tag for an order kind, or "".
func aim_icon(kind: String) -> String:
	return str(aim_icons.get(StringName(kind), ""))


## Cursor name for a target class; `armed` = an icon waits for its target.
func cursor_for(target_class: StringName, armed: bool) -> String:
	var table := target_cursors if armed else free_cursors
	return str(table.get(target_class, hud_cursor))
