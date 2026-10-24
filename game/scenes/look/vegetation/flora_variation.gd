class_name FloraVariation
extends RefCounted

## What makes two plants of one species differ. Pure functions of (seed, tag hash, cell, i) and the species'
## `VegetationSpecies.variation()`: no randi(), no RNG, so the editor, every client and every run plant the same thing.
## MeshPlanter (cells) and PatchPlanner (patches) both call `instance_transform`, `instance_color` and `write_instance`.

const SALT_TINT := 0x3C6EF372
const SALT_TINT_CELL := 0x5BD1E995
const SALT_TILT := 0x1F83D9AB
const SALT_TILT_DIR := 0x6A09E667
const SALT_STRETCH := 0x510E527F
## The tint of a blotchy species (tint_cluster_m > 0) is this share noise, the rest a per-plant hash.
const CLUSTER_WEIGHT := 0.8


## The final transform of instance i of cell (tx, tz) (a patch passes 0, 0): yaw about up, a hashed lean of up to
## `tilt_max_deg` toward a hashed direction, uniform scale in `scale_range` by `scale_u` (the unit from `cell_instances`)
## and a hashed height stretch, then `origin` and the model `pose`. Pure: `variation` is VegetationSpecies.variation().
static func instance_transform(variation: Dictionary, seed: int, tag_h: int, tx: int, tz: int, i: int, yaw: float, scale_u: float,
		origin: Vector3, pose: Transform3D) -> Transform3D:
	var range_v: Vector2 = variation["scale_range"]
	var s := lerpf(range_v.x, range_v.y, scale_u)
	var jitter: float = variation["height_jitter"]
	var tall := s * (1.0 + jitter * (FloraPlacement.unit(FloraPlacement.cell_hash(seed ^ SALT_STRETCH, tag_h, tx, tz, i)) * 2.0 - 1.0))
	var basis := Basis(Vector3.UP, yaw)
	var lean := deg_to_rad(float(variation["tilt_max_deg"])) * FloraPlacement.unit(FloraPlacement.cell_hash(seed ^ SALT_TILT, tag_h, tx, tz, i))
	if lean > 0.0:
		var toward := FloraPlacement.unit(FloraPlacement.cell_hash(seed ^ SALT_TILT_DIR, tag_h, tx, tz, i)) * TAU
		basis = Basis(Vector3(cos(toward), 0.0, sin(toward)), lean) * basis
	return Transform3D(basis.scaled_local(Vector3(s, tall, s)), origin) * pose


## The multiplier color of instance i, `tint_dark` to `tint_light`. With `tint_cluster_m` > 0 it follows value noise of
## that size at (x, z) (map meters), so neighbours share a shade; the per-plant hash is always a little of it.
static func instance_color(variation: Dictionary, seed: int, tag_h: int, tx: int, tz: int, i: int, x: float, z: float) -> Color:
	var t := FloraPlacement.unit(FloraPlacement.cell_hash(seed ^ SALT_TINT, tag_h, tx, tz, i))
	var cluster: float = variation["tint_cluster_m"]
	if cluster > 0.0:
		t = lerpf(t, value_noise(seed ^ SALT_TINT_CELL, tag_h, x / cluster, z / cluster), CLUSTER_WEIGHT)
	var dark: Color = variation["tint_dark"]
	var light: Color = variation["tint_light"]
	return dark.lerp(light, t)


## Smooth [0, 1) noise: the hashed values of the four lattice corners around (u, v), smoothstep-blended.
static func value_noise(seed: int, tag_h: int, u: float, v: float) -> float:
	var ix := floori(u)
	var iz := floori(v)
	var fx := smoothstep(0.0, 1.0, u - float(ix))
	var fz := smoothstep(0.0, 1.0, v - float(iz))
	var top := lerpf(FloraPlacement.unit(FloraPlacement.cell_hash(seed, tag_h, ix, iz, 0)), FloraPlacement.unit(FloraPlacement.cell_hash(seed, tag_h, ix + 1, iz, 0)), fx)
	var bottom := lerpf(FloraPlacement.unit(FloraPlacement.cell_hash(seed, tag_h, ix, iz + 1, 0)), FloraPlacement.unit(FloraPlacement.cell_hash(seed, tag_h, ix + 1, iz + 1, 0)), fx)
	return lerpf(top, bottom, fz)


## Writes instance `index` into a MultiMesh buffer with colors: the 12 transform floats then r, g, b, a.
static func write_instance(buffer: PackedFloat32Array, index: int, t: Transform3D, color: Color) -> void:
	MeshPlanter.write_xform(buffer, index, t)
	var at := index * MeshPlanter.XFORM_STRIDE + MeshPlanter.XFORM_STRIDE - 4
	buffer[at] = color.r
	buffer[at + 1] = color.g
	buffer[at + 2] = color.b
	buffer[at + 3] = color.a
