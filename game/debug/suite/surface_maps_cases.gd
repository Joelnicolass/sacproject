extends RefCounted

## RFC-067 cases of rules_suite (C6): the relief generator of addons/surface_maps (NormalMap-Online's Sobel / Scharr) is
## deterministic and reads the right way.
## The same picture gives the same bytes twice; a flat picture gives a flat normal (128, 128, 255 within 1); a ramp that
## brightens to the right tilts the normal left (red below 128) and one that brightens downward tilts it up (green above
## 128: OpenGL); invert_height and invert_g flip them; Scharr reads like Sobel; the edge of a cutout leaves no halo; maps
## mirror textures/<owner>/ into surfaces/<owner>/. Pictures are made here, nothing is written to disk, no tree.

const SIZE := 32


func run(_host: Node3D) -> Dictionary:
	return {"surface_maps_baker": _baker(), "surface_maps_paths": _paths()}


func _baker() -> Dictionary:
	var checks := {}
	var recipe := ReliefRecipe.new()
	var with_orm := ReliefRecipe.new()
	with_orm.orm = true
	var noise := _noise()
	var first: Dictionary = ReliefBaker.bake(noise, with_orm)
	var second: Dictionary = ReliefBaker.bake(noise, with_orm)
	checks["same_normal_bytes"] = (first.normal as Image).get_data() == (second.normal as Image).get_data()
	checks["same_orm_bytes"] = (first.orm as Image).get_data() == (second.orm as Image).get_data()
	checks["same_size"] = (first.normal as Image).get_size() == noise.get_size()
	checks["orm_only_when_asked"] = ReliefBaker.bake(noise, recipe).orm == null
	var tiled := ReliefRecipe.new()
	tiled.tile_cells = 2
	checks["tiled_same_size"] = (ReliefBaker.bake(noise, tiled).normal as Image).get_size() == noise.get_size()
	var flat: Image = ReliefBaker.bake(_filled(Color(0.4, 0.5, 0.3)), recipe).normal
	checks["flat_is_flat"] = _all_flat(flat, Rect2i(0, 0, SIZE, SIZE))
	var ramp := ReliefRecipe.new()  # no high-pass by default (it would take a straight ramp away whole)
	var right: Image = ReliefBaker.bake(_ramp(true), ramp).normal
	var down: Image = ReliefBaker.bake(_ramp(false), ramp).normal
	checks["ramp_right_tilts_left"] = right.get_pixel(SIZE / 2, SIZE / 2).r8 < 120
	checks["ramp_down_tilts_up"] = down.get_pixel(SIZE / 2, SIZE / 2).g8 > 136
	var inverted := ramp.duplicate() as ReliefRecipe
	inverted.invert_height = true
	checks["invert_flips"] = (ReliefBaker.bake(_ramp(true), inverted).normal as Image).get_pixel(SIZE / 2, SIZE / 2).r8 > 136
	var green := ramp.duplicate() as ReliefRecipe
	green.invert_g = true
	checks["invert_g_flips"] = (ReliefBaker.bake(_ramp(false), green).normal as Image).get_pixel(SIZE / 2, SIZE / 2).g8 < 120
	var scharr := ramp.duplicate() as ReliefRecipe
	scharr.filter = ReliefRecipe.Filter.SCHARR
	checks["scharr_same_sign"] = (ReliefBaker.bake(_ramp(true), scharr).normal as Image).get_pixel(SIZE / 2, SIZE / 2).r8 < 120
	checks["scharr_flat_is_flat"] = _all_flat(ReliefBaker.bake(_filled(Color(0.4, 0.5, 0.3)), scharr).normal, Rect2i(0, 0, SIZE, SIZE))
	checks["cutout_no_halo"] = _all_flat(ReliefBaker.bake(_cutout(), recipe).normal, Rect2i(0, 0, SIZE / 2, SIZE))
	checks["cutout_without_fill_halos"] = not _all_flat(ReliefBaker.bake(_cutout_opaque(), recipe).normal, Rect2i(0, 0, SIZE / 2, SIZE))
	return _verdict(checks)


func _paths() -> Dictionary:
	var checks := {}
	checks["mirrored"] = MapWriter.map_path("res://assets/original/textures/eorc/001.png", "normal") == "res://assets/surfaces/eorc/001_normal.png"
	checks["orm_name"] = MapWriter.map_path("res://assets/original/textures/casp/M000.png", "orm") == "res://assets/surfaces/casp/M000_orm.png"
	checks["own_beside"] = MapWriter.map_path("res://assets/custom/models/rock_albedo.png", "normal") == "res://assets/custom/models/rock_albedo_normal.png"
	var material := StandardMaterial3D.new()
	checks["no_albedo_no_write"] = MapWriter.write(material, {"normal": _filled(Color.GRAY)}).is_empty()
	checks["no_import_no_assign"] = not MapWriter.assign(material, {"normal": "res://nowhere/none_normal.png"})
	return _verdict(checks)


func _all_flat(normal: Image, rect: Rect2i) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := normal.get_pixel(x, y)
			if absi(c.r8 - 128) > 1 or absi(c.g8 - 128) > 1 or absi(c.b8 - 255) > 1:
				return false
	return true


func _filled(color: Color) -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image


## Brightness grows by 1/SIZE per texel to the right (`across`) or downward.
func _ramp(across: bool) -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var v := float(x if across else y) / SIZE
			image.set_pixel(x, y, Color(v, v, v))
	return image


## Left half solid mid grey, right half a hole painted black (as cutout textures are).
func _cutout() -> Image:
	var image := _filled(Color(0.6, 0.6, 0.6))
	image.fill_rect(Rect2i(SIZE / 2, 0, SIZE / 2, SIZE), Color(0.0, 0.0, 0.0, 0.0))
	return image


## The same picture with the hole solid: the black edge then does make a relief (the case above is not trivially flat).
func _cutout_opaque() -> Image:
	var image := _filled(Color(0.6, 0.6, 0.6))
	image.fill_rect(Rect2i(SIZE / 2, 0, SIZE / 2, SIZE), Color(0.0, 0.0, 0.0, 1.0))
	return image


func _noise() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 67
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			image.set_pixel(x, y, Color(rng.randf(), rng.randf(), rng.randf()))
	return image


func _verdict(checks: Dictionary) -> Dictionary:
	var bad := PackedStringArray()
	for key: String in checks:
		if not bool(checks[key]):
			bad.append(key)
	return {"ok": bad.is_empty(), "failed": bad}
