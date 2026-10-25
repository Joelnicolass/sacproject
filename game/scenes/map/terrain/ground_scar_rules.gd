class_name GroundScarRules
extends RefCounted

## The arithmetic of the marks on the ground (burns, cracks, craters), with no tree and no GPU: which 10 m tiles a mark
## touches, whether a mark is close enough to the ground to be drawn, how a mark is painted into a tile, and `Pool`, the
## fixed number of painted tiles the map can hold (the oldest one goes first). It does not own any texture (GroundScars does).
## Ref: rfcs/research/061S-scar-ground-marks.md sections 1.2, 2.1, 2.2.

## One mark pixel is this many meters; a tile of the ground is 64 of them (10 m).
const TEXEL_M := 0.15625
const TILE_TEXELS := 64
const TILE_M := 10.0
## The number of painted tiles the map can hold (the player's option) goes from MIN to MAX.
const MIN_TILES := 32
const MAX_TILES := 256
const NO_TILE := Vector2i(-1, -1)
## What the index texture holds for a painted tile: R = its layer / 255, B = this (the shader needs a value that neither a white
## nor a black default texture has). A clear tile is all zeros.
const INDEX_FLAG := 128.0 / 255.0


## The index texel of a painted tile at array layer `layer`.
static func index_color(layer: int) -> Color:
	return Color(layer / 255.0, 0.0, INDEX_FLAG, 1.0)


## The ground texel (in the map-wide grid of 0.15625 m texels) where the top-left pixel of a mark of `size` px goes when it is
## centered on `center_xz` (map meters).
static func texel_origin(center_xz: Vector2, size: Vector2i) -> Vector2i:
	return Vector2i((center_xz / TEXEL_M - Vector2(size) * 0.5).floor())


## How many 10 m tiles the map has on each side: its footprint (GroundSurface.bounds) over the tile size, rounded up.
static func grid_for(bounds: Rect2) -> Vector2i:
	return Vector2i((bounds.size / TILE_M).ceil())


## The tiles of the map a mark touches, in row order. Tiles outside the `grid` (tiles per side, see `grid_for`) are left out.
static func tiles_touched(origin: Vector2i, size: Vector2i, grid: Vector2i) -> Array[Vector2i]:
	var first := Vector2i(floori(float(origin.x) / TILE_TEXELS), floori(float(origin.y) / TILE_TEXELS))
	var last := Vector2i(floori(float(origin.x + size.x - 1) / TILE_TEXELS), floori(float(origin.y + size.y - 1) / TILE_TEXELS))
	var tiles: Array[Vector2i] = []
	for z in range(maxi(first.y, 0), mini(last.y, grid.y - 1) + 1):
		for x in range(maxi(first.x, 0), mini(last.x, grid.x - 1) + 1):
			tiles.append(Vector2i(x, z))
	return tiles


## True when a mark at height `y` is drawn over ground at `ground_y`: closer than `max_height_m` (0 or less = always).
static func allows_height(ground_y: float, y: float, max_height_m: float) -> bool:
	return max_height_m <= 0.0 or absf(ground_y - y) < max_height_m


static func clamp_capacity(count: int) -> int:
	return clampi(count, MIN_TILES, MAX_TILES)


## Paints the part of `mark` that falls inside `tile` onto `layer` (a 64 x 64 RGBA8 image of that tile), "over" with the
## mark's alpha, so marks on the same tile pile up. `origin` is the mark's top-left texel (`texel_origin`).
static func paint(layer: Image, mark: Image, origin: Vector2i, tile: Vector2i) -> void:
	var tile_origin := tile * TILE_TEXELS
	var inside := Rect2i(origin, mark.get_size()).intersection(Rect2i(tile_origin, Vector2i(TILE_TEXELS, TILE_TEXELS)))
	if inside.has_area():
		layer.blend_rect(mark, Rect2i(inside.position - origin, inside.size), inside.position - tile_origin)


## The painted tiles: which layer of the texture array holds each tile, and which one is the oldest when it is full.
## Every mark has the same priority, so the order is the order of use (a tile that gets painted again becomes the newest).
class Pool extends RefCounted:
	var capacity := 0
	## Set by the last `claim`: the layer is new for its tile (clear it before painting), and the tile it took the layer from.
	var fresh := false
	var evicted := GroundScarRules.NO_TILE
	var _layer_of: Dictionary = {}
	var _tile_of: Array[Vector2i] = []
	var _used_at := PackedInt64Array()
	var _clock := 0

	func _init(layers: int) -> void:
		capacity = layers
		_tile_of.resize(layers)
		_tile_of.fill(GroundScarRules.NO_TILE)
		_used_at.resize(layers)

	func size() -> int:
		return _layer_of.size()

	func layer_of(tile: Vector2i) -> int:
		return int(_layer_of.get(tile, -1))

	## The layer for `tile`: its own if it has one, else a free one, else the oldest's.
	func claim(tile: Vector2i) -> int:
		_clock += 1
		fresh = false
		evicted = GroundScarRules.NO_TILE
		var layer := layer_of(tile)
		if layer < 0:
			layer = _free_or_oldest()
			if _tile_of[layer] != GroundScarRules.NO_TILE:
				evicted = _tile_of[layer]
				_layer_of.erase(evicted)
			_tile_of[layer] = tile
			_layer_of[tile] = layer
			fresh = true
		_used_at[layer] = _clock
		return layer

	func _free_or_oldest() -> int:
		var oldest := 0
		for layer in capacity:
			if _tile_of[layer] == GroundScarRules.NO_TILE:
				return layer
			if _used_at[layer] < _used_at[oldest]:
				oldest = layer
		return oldest
