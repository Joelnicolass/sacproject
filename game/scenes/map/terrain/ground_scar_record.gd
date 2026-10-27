class_name GroundScarRecord
extends RefCounted

## The marks painted on the ground so far, in order, as the least that paints them again: which picture, where, and how far
## from the ground it may be. The painted tiles are derived from it; a peer that comes back after a drop gets the list of a donor
## (GroundScarsNet) and, while it catches up, merges it with what it paints itself (`merge`). Only the newest `limit` marks are kept.
## What it does not do: paint (GroundScars) or send (GroundScarsNet). No tree, no GPU.

## A mark was kept: `ordinal` is how many marks of that picture at that place the list holds now (1 = the first).
signal added(path: String, at: Vector3, max_height_m: float, ordinal: int)

const PATHS := "paths"
const MARKS := "marks"
## One per mark in `MARKS`: its `ordinal` in the donor's list.
const ORDINALS := "ordinals"
## The donor has nothing left in the air: the peer stops merging (GroundScarsNet).
const DONE := "done"
## One mark in `MARKS`: picture (index into PATHS), x, y, z (world), max height (m).
const STRIDE := 5
## Two points closer than this (m) are the same place.
const SAME_PLACE_M := 0.01

## How many of the newest marks are kept.
var limit := 2048
## While this peer catches up after a drop (GroundScarsNet), how its own marks and the donor's merge; null otherwise.
var merge: GroundScarMerge

var _paths := PackedStringArray()
var _marks := PackedFloat32Array()
var _counts: Dictionary = {}  # place key -> marks with it in the list


## Keeps a mark that was painted. A picture with no file of its own (made in code, embedded) cannot travel and is left out.
func add(texture: Texture2D, at: Vector3, max_height_m: float) -> void:
	var path := texture.resource_path if texture != null else ""
	if limit <= 0 or not travels(path):
		return
	var index := _paths.find(path)
	if index < 0:
		_paths.append(path)
		index = _paths.size() - 1
	_marks.append_array(PackedFloat32Array([index, at.x, at.y, at.z, max_height_m]))
	var key := key_of(path, at)
	_counts[key] = int(_counts.get(key, 0)) + 1
	var extra := size() - limit
	if extra > 0:
		for i in extra:
			_forget(_key_at(i))
		_marks = _marks.slice(extra * STRIDE)
	added.emit(path, at, max_height_m, int(_counts.get(key, 0)))


func size() -> int:
	return _marks.size() / STRIDE


func clear() -> void:
	_paths.clear()
	_marks.clear()
	_counts.clear()


## A peer back from a drop starts merging a donor's list (GroundScarsNet): what it painted so far counts as its own.
func begin_catch_up() -> void:
	merge = GroundScarMerge.new(_counts)


func end_catch_up() -> void:
	merge = null


## What travels: {paths, marks, ordinals}.
func to_wire() -> Dictionary:
	var ordinals := PackedInt32Array()
	var running: Dictionary = {}
	for i in size():
		var key := _key_at(i)
		running[key] = int(running.get(key, 0)) + 1
		ordinals.append(int(running[key]))
	return {PATHS: _paths, MARKS: _marks, ORDINALS: ordinals}


## One mark on the wire (a donor passing on a mark painted after its list left).
static func one(path: String, at: Vector3, max_height_m: float, ordinal: int) -> Dictionary:
	return {PATHS: PackedStringArray([path]), MARKS: PackedFloat32Array([0, at.x, at.y, at.z, max_height_m]),
			ORDINALS: PackedInt32Array([ordinal])}


## The same place for the same picture on every peer (a point rounded to SAME_PLACE_M).
static func key_of(path: String, at: Vector3) -> String:
	var cell := Vector3i((at / SAME_PLACE_M).round())
	return "%s@%d,%d,%d" % [path, cell.x, cell.y, cell.z]


static func travels(path: String) -> bool:
	return path.begins_with("res://") and not path.contains("::")


## How many marks a wire list holds (0 when it is not one).
static func count(wire: Dictionary) -> int:
	var marks: Variant = wire.get(MARKS)
	return (marks as PackedFloat32Array).size() / STRIDE if marks is PackedFloat32Array else 0


## The marks of a wire list as [texture, point, max_height_m, ordinal], in order. It comes from another peer: a mark whose
## picture is not an imported texture of the project is skipped; with no ordinals each mark counts as a first one.
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
	var ordinals: Variant = wire.get(ORDINALS)
	for i in count(wire):
		var at := i * STRIDE
		var index := int(marks[at])
		var ordinal := (ordinals as PackedInt32Array)[i] if ordinals is PackedInt32Array and i < ordinals.size() else 1
		if index >= 0 and index < textures.size() and textures[index] != null:
			out.append([textures[index], Vector3(marks[at + 1], marks[at + 2], marks[at + 3]), marks[at + 4], ordinal])
	return out


func _key_at(i: int) -> String:
	var at := i * STRIDE
	return key_of(_paths[int(_marks[at])], Vector3(_marks[at + 1], _marks[at + 2], _marks[at + 3]))


func _forget(key: String) -> void:
	var left := int(_counts.get(key, 0)) - 1
	if left > 0:
		_counts[key] = left
	else:
		_counts.erase(key)
