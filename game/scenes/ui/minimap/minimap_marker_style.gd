@tool
class_name MinimapMarkerStyle
extends Resource

## Look of one kind of minimap icon (RFC-037): a creature, the wizard, an altar... One `.tres` per kind in
## data/ui/minimap/. Sizes are HUD units (the Minimap scales them with the shared HudScale). Never mutated in a match.

enum Shape { DOT, TRIANGLE, DIAMOND, SQUARE }

## Icon art (an AtlasTexture of the `mmic` sheet). Empty draws `shape` instead.
@export var texture: Texture2D
@export var shape := Shape.DOT
## Side of the icon, in HUD units (sacengine: creatures 2, wizard 11, altar 10, Manalith 12, manafount 11).
@export_range(1.0, 32.0, 0.5) var size_px := 2.0
## The icon takes the color of its side (SideColors.side_color); off uses `fixed_color`.
@export var use_side_color := true
@export var fixed_color := Color.WHITE
## Glyph drawn at the circle's edge, pointing at the thing, when it falls outside. Empty = no arrow for this kind.
@export var arrow_texture: Texture2D
@export_range(1.0, 32.0, 0.5) var arrow_size_px := 11.0
## Arrow for this kind even when the thing is not the viewer's (the wizards).
@export var arrow_for_all := false
