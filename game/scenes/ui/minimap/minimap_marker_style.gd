@tool
class_name MinimapMarkerStyle
extends Resource

## Look of one kind of minimap icon: a creature, the wizard, an altar... One `.tres` per kind in
## data/ui/minimap/. Sizes are canvas pixels of the 1280×720 base (Godot's stretch scales them).
## Never mutated in a match.

enum Shape { DOT, TRIANGLE, DIAMOND, SQUARE }

## Icon art (an AtlasTexture of the `mmic` sheet). Empty draws `shape` instead.
@export var texture: Texture2D
@export var shape := Shape.DOT
## Side of the icon, in canvas pixels (creatures 2.5, wizard 13, altar 12, Manalith 14.5, manafount
## 13).
@export_range(1.0, 40.0, 0.5) var size_px := 2.5
## The icon takes the color of its side (SideColors.side_color); off uses `fixed_color`.
@export var use_side_color := true
@export var fixed_color := Color.WHITE
## Glyph drawn at the circle's edge, pointing at the thing, when it falls outside. Empty = no arrow
## for this kind.
@export var arrow_texture: Texture2D
@export_range(1.0, 40.0, 0.5) var arrow_size_px := 13.0
## Arrow for this kind even when the thing is not the viewer's (the wizards).
@export var arrow_for_all := false
