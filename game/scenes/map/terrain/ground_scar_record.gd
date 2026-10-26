class_name GroundScarRecord
extends RefCounted

## The marks painted on the ground so far, in order, as the least that paints them again: which picture, where, and how far
## from the ground it may be. The painted tiles are derived from it; a peer that comes back after a drop gets this list and
## paints it again (GroundScarsNet). Only the newest `limit` marks are kept (older ones are long gone from the tiles anyway).
## What it does not do: paint (GroundScars) or send (GroundScarsNet). No tree, no GPU.

const PATHS := "paths"
const MARKS := "marks"
## One mark in `MARKS`: picture (index into PATHS), x, y, z (world), max height (m).
const STRIDE := 5

## How many of the newest marks are kept.
var limit := 2048

var _paths := PackedStringArray()
var _marks := PackedFloat32Array()


## Keeps a mark that was painted. A picture with no file of its own (made in code, embedded) cannot travel and is left out.
func add(texture: Texture2D, at: Vector3, max_height_m: float) -> void:
	var path := texture.resource_path if texture != null else ""
	if limit <= 0 or not path.begins_with("res://") or path.contains("::"):
		return
	var index := _paths.find(path)
	if index < 0:
		_paths.append(path)
		index = _paths.size() - 1
	_marks.append_array(PackedFloat32Array([index, at.x, at.y, at.z, max_height_m]))
	var extra := size() - limit
	if extra > 0:
		_marks = _marks.slice(extra * STRIDE)


func size() -> int:
	return _marks.size() / STRIDE


func clear() -> void:
	_paths.clear()
	_marks.clear()


## What travels: {paths, marks}.
func to_wire() -> Dictionary:
	return {PATHS: _paths, MARKS: _marks}


## How many marks a wire list holds (0 when it is not one).
static func count(wire: Dictionary) -> int:
	var marks: Variant = wire.get(MARKS)
	return (marks as PackedFloat32Array).size() / STRIDE if marks is PackedFloat32Array else 0


## The marks of a wire list as [texture, point, max_height_m], in order. It comes from another peer: a mark whose picture is not
## an imported texture of the project is skipped.
static func entries(wire: Dictionary) -> Array:
	var out: Array = []
	var paths: Variant = wire.get(PATHS)
	if not paths is PackedStringArray or count(wire) == 0:
		return out
	var textures: Array[Texture2D] = []
	for path: String in paths:
		var ok := path.begins_with("res://") and ResourceLoader.exists(path, "Texture2D")
		textures.append(load(path) as Texture2D if ok else null)
	var marks := wire[MARKS] as PackedFloat32Array
	for i in count(wire):
		var at := i * STRIDE
		var index := int(marks[at])
		if index >= 0 and index < textures.size() and textures[index] != null:
			out.append([textures[index], Vector3(marks[at + 1], marks[at + 2], marks[at + 3]), marks[at + 4]])
	return out
