@tool
class_name BodySize
extends Resource

## The measures of one body or prop (RFC-036 036c): box, capsule radius, height, reach and the turn that stands the mesh up.
## Baked once by tools/bake_catalog.gd into data/catalog/body_sizes/<tag>.tres; BodyCatalog reads it through GameCatalog.
## The hand corrections of a pose are not here: they go on top, in data/bodies/pose_overrides.tres.

@export var tag := ""
## A prop (static mesh in assets/original/props/) instead of an animated body.
@export var is_prop := false
## Minimum corner then size: x, y, z, w, h, d.
@export var box := PackedFloat64Array()
@export var foot_offset := 0.0
@export var height := 0.0
@export var radius := 0.0
@export var reach := 0.0
## Degrees about x, y, z that stand the static mesh upright.
@export var upright_fix := PackedFloat64Array()
## Body that supplies the pose; empty when the record had none.
@export var pose_source := ""
## Only meaningful when `has_upright_checked`.
@export var upright_checked := false
@export var has_upright_checked := false


## The record BodyCatalog has always read (plain Arrays of floats).
func to_record() -> Dictionary:
	var record := {
		"box": Array(box),
		"foot_offset": foot_offset,
		"height": height,
		"radius": radius,
		"reach": reach,
		"upright_fix": Array(upright_fix),
	}
	if not pose_source.is_empty():
		record["pose_source"] = pose_source
	if has_upright_checked:
		record["upright_checked"] = upright_checked
	return record
