class_name PortalLook
extends Resource

## Look of a flat ring + glowing center that faces the camera (sacengine SacVortex, sacobject.d:4045-4108,
## renderer.d:222-239). One .tres per colour: data/fx/portal_blue.tres (the carried creature's ring),
## data/fx/portal_red.tres (the Sac Doctor's vortex). The two 4x4 atlases are dragged in here.

## The 4x4 atlas of the ring (rim): ltn2.png blue, vtx1.png red. Empty (or no `center`) = a flat `fallback_color` fill.
@export var rim: Texture2D
## The 4x4 atlas of the center sprite: vtx3.png blue, vtx2.png red.
@export var center: Texture2D
## Color multiplier of the shadeless material (HDR). sacengine: rim 10, center 1 (renderer.d:222-239).
@export_range(0.0, 40.0, 0.1) var rim_energy := 10.0
@export_range(0.0, 40.0, 0.1) var center_energy := 1.0
## Seconds each of the 16 atlas cells stays (0.53 s per cycle).
## Ref: 2 ticks at 60 Hz, sacobject.d:4101-4105.
@export_range(0.005, 0.5, 0.0001, "suffix:s") var frame_s := 0.0333
## Inner radius of the ring as a fraction of the outer one: thickness 0.35 (sacobject.d:4079).
@export_range(0.05, 0.95, 0.01) var inner_ratio := 0.65
## The ring texture is mirrored this many times around it (16 cells of the zigzag, sacobject.d:4062-4093).
@export_range(1.0, 64.0, 1.0) var zigzag_repeats := 16.0
## Filling when an atlas is missing (not from the original).
@export var fallback_color := Color(0.3, 0.7, 1.0)
