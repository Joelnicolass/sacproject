extends Node3D

## Playtest scene of VegetationPatch (RFC-055 055d-d3): the flat test map, one patch of ferns and one house on top of it.
## The house brings its own VegetationClear, so the patch leaves a bare circle around it. Move the house or the patch in
## the editor (or in the remote tree) and the ferns plant again. Run it with F6; it applies `quality` to the map's look
## because nothing in this scene does (the game does it with its graphics options).

@export var map: MapRoot
@export var quality: LookQuality


func _ready() -> void:
	if map and map.look and quality:
		map.look.apply_quality(quality)
