@tool
class_name TerrainBrush
extends Resource

## The brush every map tool shares (raise and lower, smooth and flatten, void and fill, the ground's roles, flora): how far
## it reaches, how soft its edge is, its shape, how fast it raises, and for pictures how far a dab moves a pixel (flow) and
## what flora it leaves (density). A preset is another `.tres`. Not: painting (BrushRules, PaintRules, the canvases), the
## tool bar or the cursor.

## The outline of the brush seen from above.
enum Shape {
	CIRCLE,  ## a disc of radius `size_m`
	SQUARE,  ## a square `2 * size_m` wide
	CROSS,  ## a plus sign `2 * size_m` long, each arm a third of that wide
}

## From the centre to the edge of the brush (the brush is twice this wide). Weight 0 at this distance.
@export_range(5.0, 500.0, 1.0, "or_greater", "suffix:m") var size_m := 50.0
## 0 = hard edge (full strength up to `size_m`); 1 = soft all the way from the centre.
@export_range(0.0, 1.0, 0.01) var falloff := 0.5
@export var shape := Shape.CIRCLE
## Raise and lower: metres the centre moves for each pixel the mouse is dragged up (down lowers).
@export_range(0.01, 2.0, 0.01, "or_greater", "suffix:m/px") var strength_m := 0.1
## Pictures (roles, flora): how far one dab moves a pixel toward the paint (1 = all the way under the hard core).
@export_range(0.0, 1.0, 0.01) var flow := 0.5
## Flora: the density a full dab leaves (1 = the layer's max_per_cell, white).
@export_range(0.0, 1.0, 0.01) var density := 1.0
