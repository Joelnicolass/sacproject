@tool
class_name TerrainStatus
extends Node

## What the ground of the map holds right now, read only in the inspector (Remote → Terrain/Status during a match): how many
## changes stayed, how many times it moved, the stamps playing, the holes, and a picture of it. It only reads its `terrain`;
## it changes nothing and costs nothing until the inspector asks (the picture only with `show_view`).

## The ground it reads (its parent Terrain).
@export var terrain: Terrain
## Shows `view`: a picture of how far each vertex moved (R, metres) and the holes (G = 1). Costs a copy of the lattice per change.
@export var show_view := false

@export_group("State (read only)")
## Changes that stayed since loading (a peer that joins late compares it).
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var rev: int:
	get:
		return terrain.field().rev if terrain != null else 0
## Times the ground moved, the stamps that play included.
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var version: int:
	get:
		return terrain.field().version if terrain != null else 0
## The stamps playing now (their node paths).
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var live_stamps: PackedStringArray:
	get:
		return terrain.field().live_keys() if terrain != null else PackedStringArray()
## The lattice ids of the vertices taken away (row * 256 + column).
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)
var holes: PackedInt32Array:
	get:
		return terrain.field().removed_ids() if terrain != null else PackedInt32Array()
## The picture of the ground's shift (only with `show_view`).
@export_custom(
	PROPERTY_HINT_RESOURCE_TYPE, "Texture2D", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
)
var view: Texture2D:
	get:
		return _view() if show_view and terrain != null else null

var _view_texture: ImageTexture
var _view_version := -1


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if terrain != null
		else PackedStringArray(["The `terrain` socket is missing (the map's Terrain)."])
	)


func _view() -> Texture2D:
	var ground := terrain.field()
	if _view_version != ground.version:
		_view_version = ground.version
		var picture := Image.create_from_data(
			ground.size.x, ground.size.y, false, Image.FORMAT_RGF, ground.texels.to_byte_array()
		)
		_view_texture = ImageTexture.create_from_image(picture)
	return _view_texture
