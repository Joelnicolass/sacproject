class_name FloraDensity
extends RefCounted

## A snapshot of the FloraLayer nodes of a map, as MeshPlanter reads it: per layer its species tag, its density image
## (L8 bytes, 1 px = `cell_m`) and `max_per_cell`. Plain arrays of values, so WorkerThreadPool tasks can read it while the
## main thread does not touch it (a layer that changes makes a new snapshot). Count of a pixel: round(value x max / 255),
## exact for the images the migration wrote (value = round(count x 255 / max), max <= 255).
## Presentation data: the simulation never reads it.

var tags := PackedStringArray()
var species: Array[VegetationSpecies] = []
var _cell_m := PackedFloat32Array()
var _max := PackedInt32Array()
var _width := PackedInt32Array()
var _height := PackedInt32Array()
var _bytes: Array[PackedByteArray] = []


## One entry per layer that has a species and an image (in the order given).
static func from_layers(layers: Array) -> FloraDensity:
	var snapshot := FloraDensity.new()
	for layer: FloraLayer in layers:
		if layer.species == null or layer.density == null:
			continue
		var image := layer.density.get_image()
		if image == null or image.is_empty():
			continue
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_L8)
		snapshot.tags.append(layer.species.density_tag())
		snapshot.species.append(layer.species)
		snapshot._cell_m.append(layer.cell_m)
		snapshot._max.append(layer.max_per_cell)
		snapshot._width.append(image.get_width())
		snapshot._height.append(image.get_height())
		snapshot._bytes.append(image.get_data())
	return snapshot


## The FloraLayer nodes in the tree under `scope` (not the ones leaving it) as a snapshot.
static func gather(scope: Node) -> FloraDensity:
	var layers := []
	for node in scope.get_tree().get_nodes_in_group(FloraLayer.GROUP):
		if node.is_inside_tree() and not node.is_queued_for_deletion() and scope.is_ancestor_of(node):
			layers.append(node)
	return from_layers(layers)


func entries() -> int:
	return tags.size()


func cell_m(index: int) -> float:
	return _cell_m[index]


## Plants of entry `index` in the cell (tx, tz); 0 outside the image.
func count_at(index: int, tx: int, tz: int) -> int:
	if index < 0 or index >= _bytes.size() or tx < 0 or tz < 0 or tx >= _width[index] or tz >= _height[index]:
		return 0
	return roundi(_bytes[index][tz * _width[index] + tx] * _max[index] / 255.0)


func tag_index(tag: String) -> int:
	return tags.find(tag)


## Plants of one entry over its whole image.
func tag_total(index: int) -> int:
	var sum := 0
	for tz in _height[index]:
		for tx in _width[index]:
			sum += count_at(index, tx, tz)
	return sum


func total() -> int:
	var sum := 0
	for index in tags.size():
		sum += tag_total(index)
	return sum
