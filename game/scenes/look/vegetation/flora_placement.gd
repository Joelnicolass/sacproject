class_name FloraPlacement
extends RefCounted

## Where the plants of one cell stand. Pure functions of (seed, tag, cell, count): no randi(), no
## global RNG, no match RNG, so the editor, every client and every run plant the same thing.
## - `instance_count`: n = round_stochastic(count x density_scale), the rounding decided by the cell's hash, so a cell
##   never differs from count x scale by 1 or more.
## - `cell_instances`: instance i of a cell has its offset, yaw and scale from the hash of (seed, tag, tx, tz, i).
##   The offsets are stratified by the index: the base-4 digits of i, lowest first, pick nested quadrants of the cell
##   (each level's choice shuffled by a hash of the path so far, Owen scrambling), plus a hashed jitter inside the
##   smallest box. So instances 0-3 fall in the four quadrants, 0-15 in the sixteen sub-quadrants, and so on: any prefix
##   is an even sample of the cell, which is what lets the LOD draw a prefix (`visible_instance_count`).
## Integers are kept to 32 bits with `MASK`; `_mul32` splits the product so it never overflows 64 bits.

const MASK := 0xFFFFFFFF
## Floats per instance in `cell_instances`: x, z (map meters), yaw (radians), scale.
const STRIDE := 4
## Quadrant levels of the stratification: 4^4 = 256 boxes, more than the largest count (255).
const LEVELS := 4
const SALT_COUNT := 0x51ED27
const SALT_PATH := 0x2C1B3C6D
const SALT_JITTER_X := 0x297A2D39
const SALT_JITTER_Z := 0x1B873593
const SALT_YAW := 0x68E31DA4
const SALT_SCALE := 0x0B4F2E1D


## Stable hash of a tag (FNV-1a over its UTF-8 bytes); String.hash() is not promised to stay the same across versions.
static func tag_hash(tag: String) -> int:
	var h := 0x811C9DC5
	for byte in tag.to_utf8_buffer():
		h = _mul32(h ^ byte, 0x01000193)
	return h


## Hash of (seed, tag hash, tx, tz, i) as an unsigned 32-bit int.
static func cell_hash(seed: int, tag_h: int, tx: int, tz: int, i: int) -> int:
	var h := _mix(seed & MASK)
	h = _mix(h ^ (tag_h & MASK))
	h = _mix(h ^ (tx & MASK))
	h = _mix(h ^ (tz & MASK))
	return _mix(h ^ (i & MASK))


## [0, 1) from a 32-bit hash (its top 24 bits).
static func unit(h: int) -> float:
	return float((h & MASK) >> 8) / 16777216.0


## How many of the cell's `count` plants a density scale keeps: floor(count x scale), plus one with a probability equal to
## the fraction, decided by the cell's own hash.
static func instance_count(
	seed: int, tag: String, tx: int, tz: int, count: int, density_scale: float
) -> int:
	if count <= 0 or density_scale <= 0.0:
		return 0
	var exact := float(count) * density_scale
	var whole := floori(exact)
	var fraction := exact - float(whole)
	if fraction > 0.0 and unit(cell_hash(seed ^ SALT_COUNT, tag_hash(tag), tx, tz, 0)) < fraction:
		whole += 1
	return whole


## The first `n` instances of cell (tx, tz) of a `texel_m` grid, STRIDE floats each: x, z in map meters, yaw in [0, TAU),
## scale in [scale_range.x, scale_range.y]. Any prefix of the result is the result for a smaller n.
static func cell_instances(
	seed: int, tag: String, tx: int, tz: int, n: int, texel_m: float, scale_range := Vector2.ONE
) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(maxi(n, 0) * STRIDE)
	var tag_h := tag_hash(tag)
	var origin := Vector2(tx, tz) * texel_m
	for i in maxi(n, 0):
		var local := _stratified(seed, tag_h, tx, tz, i)
		out[i * STRIDE] = origin.x + local.x * texel_m
		out[i * STRIDE + 1] = origin.y + local.y * texel_m
		out[i * STRIDE + 2] = unit(cell_hash(seed ^ SALT_YAW, tag_h, tx, tz, i)) * TAU
		out[i * STRIDE + 3] = lerpf(
			scale_range.x, scale_range.y, unit(cell_hash(seed ^ SALT_SCALE, tag_h, tx, tz, i))
		)
	return out


## Offset in [0, 1)^2 of instance i inside its cell (see the header).
static func _stratified(seed: int, tag_h: int, tx: int, tz: int, i: int) -> Vector2:
	var u := 0.0
	var v := 0.0
	var size := 0.5
	var path := 1
	var digits := i
	for level in LEVELS:
		# The permutation of this level depends on the quadrants chosen above it (path), so sibling boxes shuffle apart.
		var shuffle := cell_hash(seed ^ SALT_PATH, tag_h, tx, tz, path * 8 + level) & 3
		var quadrant := (digits & 3) ^ shuffle
		u += size * float(quadrant & 1)
		v += size * float(quadrant >> 1)
		path = path * 4 + quadrant
		digits >>= 2
		size *= 0.5
	var box := size * 2.0
	u += box * unit(cell_hash(seed ^ SALT_JITTER_X, tag_h, tx, tz, i))
	v += box * unit(cell_hash(seed ^ SALT_JITTER_Z, tag_h, tx, tz, i))
	return Vector2(u, v)


## murmur3's 32-bit finalizer.
static func _mix(h: int) -> int:
	h &= MASK
	h ^= h >> 16
	h = _mul32(h, 0x85EBCA6B)
	h ^= h >> 13
	h = _mul32(h, 0xC2B2AE35)
	h ^= h >> 16
	return h


## (a x b) mod 2^32 for 32-bit a and b, in two products under 2^48.
static func _mul32(a: int, b: int) -> int:
	a &= MASK
	return (a * (b & 0xFFFF) + (((a * ((b >> 16) & 0xFFFF)) & 0xFFFF) << 16)) & MASK
