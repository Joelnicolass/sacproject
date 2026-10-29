class_name GroundTextures
extends RefCounted

## The textures the ground shader reads, built at runtime and never saved: the four roles of a
## `GodGround` packed into one `Texture2DArray` per kind of map (albedo, normal, ORM, grain), so the
## shader uses 4 samplers instead of 16 (the web build needs it), and the seamless noise shared by
## the ground and the grass. Cached by the maps they are made of.
## What it does NOT do: set uniforms (GroundMaterial does) or decide the look.

enum Kind { ALBEDO, NORMAL, ORM, DETAIL }

const NOISE_SIZE := 256
## What a role with no map of a kind shows: plain grey, a flat normal, no occlusion and full
## roughness, a mid grain.
const FALLBACK := {
	Kind.ALBEDO: Color(0.5, 0.5, 0.5),
	Kind.NORMAL: Color(0.5, 0.5, 1.0),
	Kind.ORM: Color(1.0, 1.0, 0.5),
	Kind.DETAIL: Color(0.5, 0.5, 0.5),
}

## [kind, map of role 0, 1, 2, 3] -> Texture2DArray. Keyed by the maps themselves: a new tint never
## rebuilds, a new map does.
static var _cache := {}
static var _noise: ImageTexture


## The array of `kind` for the four roles of `ground` (layer i = channel i of ground_roles.png).
## Null without a ground.
static func array_of(ground: GodGround, kind: Kind) -> Texture2DArray:
	if ground == null:
		return null
	var key: Array = [kind]
	for role in ground.roles():
		key.append(_texture_of(role, kind) if role else null)
	if not _cache.has(key):
		_cache[key] = _build(key.slice(1), kind)
	return _cache[key]


## True when the role has its own map of `kind` (the shader skips the normal and ORM work for the
## others).
static func has_map(role: GroundRole, kind: Kind) -> bool:
	return role != null and _texture_of(role, kind) != null


## Four uncorrelated seamless noises in RGBA (wind, patches, the ragged borders between roles).
static func noise() -> ImageTexture:
	if _noise == null:
		_noise = _build_noise()
	return _noise


static func _texture_of(role: GroundRole, kind: Kind) -> Texture2D:
	match kind:
		Kind.ALBEDO:
			return role.albedo
		Kind.NORMAL:
			return role.normal
		Kind.ORM:
			return role.orm
	return role.detail


## Every layer of an array takes the size of the first map found; a map of another size is scaled to
## it, with a warning (keep the four maps of a kind the same size). A role without that map gets the
## fallback colour.
static func _build(textures: Array, kind: Kind) -> Texture2DArray:
	var images: Array[Image] = []
	var size := Vector2i.ZERO
	for texture: Texture2D in textures:
		var image := texture.get_image() if texture else null
		if image != null and image.is_compressed():
			image.decompress()
		if image != null and size == Vector2i.ZERO:
			size = image.get_size()
		images.append(image)
	if size == Vector2i.ZERO:
		size = Vector2i(4, 4)
	for i in images.size():
		var image := images[i]
		if image == null:
			image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
			image.fill(FALLBACK[kind])
		else:
			image = image.duplicate() as Image
			image.clear_mipmaps()
			image.convert(Image.FORMAT_RGBA8)
			if image.get_size() != size:
				push_warning(
					(
						# gdlint: ignore=max-line-length
						"GroundTextures: the %s maps of a GodGround differ in size; scaling one to %s."
						% [Kind.keys()[kind], size]
					)
				)
				image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		images[i] = image
	var array := Texture2DArray.new()
	array.create_from_images(images)
	return array


static func _build_noise() -> ImageTexture:
	var side := NOISE_SIZE
	var channels: Array[PackedByteArray] = []
	for c in 4:
		var generator := FastNoiseLite.new()
		generator.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		generator.frequency = 6.0 / float(side)
		generator.fractal_octaves = 4
		generator.seed = 7022 + c * 101
		var image := generator.get_seamless_image(side, side, false, false, 0.1, true)
		image.convert(Image.FORMAT_L8)
		channels.append(image.get_data())
	var rgba := PackedByteArray()
	rgba.resize(side * side * 4)
	for i in side * side:
		for c in 4:
			rgba[i * 4 + c] = channels[c][i]
	var noise_image := Image.create_from_data(side, side, false, Image.FORMAT_RGBA8, rgba)
	noise_image.generate_mipmaps()
	return ImageTexture.create_from_image(noise_image)
