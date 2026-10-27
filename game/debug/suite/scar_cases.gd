extends RefCounted

## RFC-061 061k-5 cases of rules_suite: the marks on the ground. The arithmetic (tiles a mark touches, the oldest tile goes first, the
## height filter, painting "over" and piling up), the imported SCAR pictures (19, with their sizes), the headless node that does
## nothing, and the wiring: every map has its GroundScars, both ground shaders read the marks, and each effect that burns the ground
## has its ScarMark with the texture and height of the table in rfcs/research/061S-scar-ground-marks.md. No window, no network.
## The reader (tools/import/sac_formats/scar.py) checks `size = 16 + 1024 + 2*w*h` on all 19 while the importer runs.

const SCARS_DIR := "res://assets/original/scars/"
## Tiles per side of the grid map (2560 m / 10 m), what `GroundScarRules.grid_for` gives its footprint.
const GRID := Vector2i(256, 256)
## Pixels of the 19 pictures (061S section 1.4).
const SIZES := {
	"scar": Vector2i(52, 51), "volc": Vector2i(256, 256), "oils": Vector2i(64, 64), "mean": Vector2i(64, 64),
	"bovs": Vector2i(128, 128), "quk1": Vector2i(16, 16), "blud": Vector2i(8, 8), "rcrk": Vector2i(64, 64),
	"air_": Vector2i(128, 128), "deth": Vector2i(128, 128), "erth": Vector2i(128, 128), "fire": Vector2i(128, 128),
	"life": Vector2i(128, 128), "tscr": Vector2i(40, 40), "gscr": Vector2i(40, 40), "escr": Vector2i(256, 256),
	"bscr": Vector2i(16, 16), "ecrk": Vector2i(48, 48), "jm2d": Vector2i(48, 48),
}


var _host: Node3D


func run(host: Node3D) -> Dictionary:
	_host = host
	return {
		"scar_files": _files(),
		"scar_tiles_touched": _tiles_touched(),
		"scar_origin": _origin(),
		"scar_pool": _pool(),
		"scar_height": _height(),
		"scar_paint": _paint(),
		"scar_headless": _headless(),
		"scar_option": _option(),
		"scar_maps": _maps(),
		"scar_shaders": _shaders(),
		"scar_effects": _effects(),
		"scar_record": _record(),
		"scar_catch_up": _catch_up(),
	}


func _files() -> Dictionary:
	var wrong := PackedStringArray()
	for tag in SIZES:
		var texture := load(SCARS_DIR + tag + ".png") as Texture2D
		if texture == null or Vector2i(texture.get_size()) != SIZES[tag]:
			wrong.append(tag)
	return {"ok": SIZES.size() == 19 and wrong.is_empty(), "wrong": wrong}


## A 256 x 256 mark (40 m) touches up to 5 x 5 = 25 tiles of 10 m; aligned to the tile grid it touches 4 x 4; one pixel more and a row is added.
func _tiles_touched() -> Dictionary:
	var big := Vector2i(256, 256)
	var checks := {}
	checks["offset_25"] = GroundScarRules.tiles_touched(Vector2i(32, 32), big, GRID).size() == 25
	checks["aligned_16"] = GroundScarRules.tiles_touched(Vector2i(128, 64), big, GRID).size() == 16
	checks["small_in_one"] = _same(GroundScarRules.tiles_touched(Vector2i(70, 70), Vector2i(16, 16), GRID), [Vector2i(1, 1)])
	checks["small_on_corner"] = GroundScarRules.tiles_touched(Vector2i(60, 60), Vector2i(16, 16), GRID).size() == 4
	checks["off_the_map_left_out"] = _same(GroundScarRules.tiles_touched(Vector2i(-40, -40), Vector2i(64, 64), GRID), [Vector2i(0, 0)])
	checks["grid_from_bounds"] = GroundScarRules.grid_for(Rect2(0.0, 0.0, 2560.0, 2560.0)) == GRID and GroundScarRules.grid_for(Rect2(0.0, 0.0, 2561.0, 100.0)) == Vector2i(257, 10)
	checks["rim"] = _same(GroundScarRules.tiles_touched(Vector2i(256 * 64 - 8, 10), Vector2i(16, 16), GRID), [Vector2i(255, 0)])
	return _result(checks)


func _origin() -> Dictionary:
	var checks := {}
	checks["centered"] = GroundScarRules.texel_origin(Vector2(100.0, 100.0), Vector2i(64, 64)) == Vector2i(608, 608)
	checks["meter_is_6_4_texels"] = is_equal_approx(GroundScarRules.TILE_M / GroundScarRules.TEXEL_M, 64.0)
	checks["odd_size"] = GroundScarRules.texel_origin(Vector2(10.0, 10.0), Vector2i(51, 51)) == Vector2i(38, 38)
	return _result(checks)


## With a limit of 32 the 33rd tile takes the layer of the oldest; painting a tile again makes it the newest; every mark is equal.
func _pool() -> Dictionary:
	var checks := {}
	var pool := GroundScarRules.Pool.new(GroundScarRules.MIN_TILES)
	for i in 32:
		pool.claim(Vector2i(i, 0))
	checks["full"] = pool.size() == 32
	var layer_of_first := pool.layer_of(Vector2i(0, 0))
	pool.claim(Vector2i(1, 0))
	checks["old_tile_kept_its_layer"] = not pool.fresh and pool.layer_of(Vector2i(1, 0)) >= 0
	var layer := pool.claim(Vector2i(100, 0))
	checks["oldest_goes"] = pool.evicted == Vector2i(0, 0) and layer == layer_of_first and pool.fresh
	checks["still_32"] = pool.size() == 32 and pool.layer_of(Vector2i(0, 0)) == -1
	pool.claim(Vector2i(101, 0))
	checks["touched_again_stays"] = pool.evicted == Vector2i(2, 0) and pool.layer_of(Vector2i(1, 0)) >= 0
	checks["limits"] = GroundScarRules.clamp_capacity(5) == 32 and GroundScarRules.clamp_capacity(999) == 256 and GroundScarRules.clamp_capacity(100) == 100
	return _result(checks)


func _height() -> Dictionary:
	var checks := {}
	checks["near"] = GroundScarRules.allows_height(10.0, 11.5, 2.5)
	checks["above"] = not GroundScarRules.allows_height(10.0, 13.0, 2.5)
	checks["below"] = not GroundScarRules.allows_height(10.0, 7.0, 2.5)
	checks["limit_is_open"] = not GroundScarRules.allows_height(0.0, 2.5, 2.5)
	checks["zero_means_always"] = GroundScarRules.allows_height(0.0, 500.0, 0.0)
	return _result(checks)


## "Over" with the mark's alpha: two half-clear marks on the same tile give 3/4, the part outside the tile is cut, the colour stays.
func _paint() -> Dictionary:
	var checks := {}
	var mark := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	mark.fill(Color(1.0, 0.0, 0.0, 0.5))
	var layer := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	GroundScarRules.paint(layer, mark, Vector2i(60, 60), Vector2i(0, 0))
	var once := layer.get_pixel(62, 62)
	checks["alpha_once"] = absf(once.a - 0.5) < 0.02 and once.r > 0.99
	checks["cut_at_the_tile"] = layer.get_pixel(63, 63).a > 0.4 and layer.get_pixel(59, 59).a == 0.0
	GroundScarRules.paint(layer, mark, Vector2i(60, 60), Vector2i(0, 0))
	checks["piles_up"] = absf(layer.get_pixel(62, 62).a - 0.75) < 0.02
	var next := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	GroundScarRules.paint(next, mark, Vector2i(60, 60), Vector2i(1, 0))
	checks["other_tile_gets_the_rest"] = next.get_pixel(0, 62).a > 0.4 and next.get_pixel(4, 62).a == 0.0
	var far := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	GroundScarRules.paint(far, mark, Vector2i(60, 60), Vector2i(5, 5))
	checks["untouched_tile_stays_clear"] = far.get_pixel(0, 0).a == 0.0 and far.get_pixel(63, 63).a == 0.0
	return _result(checks)


## Without a window the node holds nothing and every request answers no.
func _headless() -> Dictionary:
	if DisplayServer.get_name() != "headless":
		return {"ok": true, "skipped": "this run has a window"}
	var checks := {}
	var scars := (load("res://scenes/map/terrain/ground_scars.tscn") as PackedScene).instantiate() as GroundScars
	var mark := (load("res://scenes/spells/marks/rock_mark.tscn") as PackedScene).instantiate() as ScarMark
	var host := Node3D.new()
	_host.add_child(host)
	host.add_child(scars)
	host.add_child(mark)
	checks["inactive"] = not scars.is_active()
	checks["no_stamp"] = not scars.stamp(mark.texture, Vector3(100.0, 0.0, 100.0))
	checks["mark_answers_no"] = not mark.mark()
	checks["of_finds_nothing"] = GroundScars.of(mark) == null
	checks["nothing_painted"] = scars.painted_tiles() == 0
	host.free()
	return _result(checks)


func _option() -> Dictionary:
	var prefs := load(GraphicsPrefs.SHARED_PATH) as GraphicsPrefs
	var checks := {}
	checks["default_256"] = prefs.default_scar_tiles == 256
	checks["inside_limits"] = prefs.scar_tiles() >= 32 and prefs.scar_tiles() <= 256
	var node := (load("res://scenes/map/terrain/ground_scars.tscn") as PackedScene).instantiate()
	checks["node_reads_the_option"] = node.get("prefs") == prefs
	node.free()
	return _result(checks)


## Every map scene (and the scaffold that writes new ones) instances terrain.tscn, whose GroundScars is wired to its Terrain.
func _maps() -> Dictionary:
	var missing := PackedStringArray()
	var dir := DirAccess.open("res://scenes/map/maps")
	for map_dir in dir.get_directories():
		var text := FileAccess.get_file_as_string("res://scenes/map/maps/%s/map.tscn" % map_dir)
		if not text.contains('path="res://scenes/map/terrain/terrain.tscn"'):
			missing.append(map_dir)
	var ground := (load("res://scenes/map/terrain/terrain.tscn") as PackedScene).instantiate()
	var scars := ground.get_node_or_null("GroundScars") as GroundScars
	var wired := scars != null and scars.terrain == ground
	ground.free()
	var scaffold := FileAccess.get_file_as_string("res://tools/import/scaffold_map.py")
	return {"ok": missing.is_empty() and wired and dir.get_directories().size() >= 9 and scaffold.contains("scenes/map/terrain/terrain.tscn"), "missing": missing}


func _shaders() -> Dictionary:
	var checks := {}
	for path in ["res://scenes/look/ground/ground.gdshader"]:
		var text := FileAccess.get_file_as_string(path)
		checks[path.get_file()] = text.contains("ground_scars.gdshaderinc") and text.contains("ground_scar_mix(")
	var globals := FileAccess.get_file_as_string("res://project.godot")
	checks["globals"] = globals.contains("scar_index={") and globals.contains("scar_tiles={")
	return _result(checks)


## Texture and height of each effect that burns the ground (the table other cuts copy from).
func _effects() -> Dictionary:
	var checks := {}
	checks["explosion"] = _child_mark("res://scenes/spells/zones/explosion_burst.tscn", "Scar", "scar", 10.0)
	checks["lightning"] = _child_mark("res://scenes/fx/burning_beam_fx.tscn", "Scar", "scar", 2.5)
	var beam := (load("res://scenes/fx/burning_beam_fx.tscn") as PackedScene).instantiate() as BeamFx
	var bolt_mark := beam.get_node("Scar") as ScarMark
	checks["bolt_calls_the_mark"] = beam.struck.is_connected(bolt_mark.mark_at)
	checks["bolt_types"] = _beam_scene("lightning") and _beam_scene("lightning_ltng") and not _beam_scene("lightning_small")
	beam.free()
	checks["oil"] = _scene_mark("res://scenes/spells/marks/oil_mark.tscn", "oils", 10.0)
	checks["rock"] = _scene_mark("res://scenes/spells/marks/rock_mark.tscn", "gscr", 5.0)
	var oil_look := ShotLook.make(load("res://data/shots/kcfa.tscn") as PackedScene)
	var halo_look := ShotLook.make(load("res://data/shots/halo_rock.tscn") as PackedScene)
	checks["oil_shot"] = oil_look.ground_mark != null
	checks["halo_shot"] = halo_look.ground_mark != null
	oil_look.free()
	halo_look.free()
	var rock := (load("res://scenes/spells/rock_projectile.tscn") as PackedScene).instantiate()
	checks["rock_spell"] = rock.get("ground_mark") != null
	rock.free()
	checks["firewall"] = _child_mark("res://scenes/spells/walls/firewall.tscn", "Mark", "quk1", 0.0) and _wall_scars("res://scenes/spells/walls/firewall.tscn")
	checks["wall_of_spikes"] = _child_mark("res://scenes/spells/walls/wall_of_spikes.tscn", "Mark", "gscr", 0.0) and _wall_scars("res://scenes/spells/walls/wall_of_spikes.tscn")
	return _result(checks)


## A wall paints its cracks with the ScarMark of its scene, wired to its own wall.
func _wall_scars(path: String) -> bool:
	var root := (load(path) as PackedScene).instantiate()
	var scars := root.get_node("Scars") as WallScars
	var ok := scars != null and scars.wall == root and scars.mark == root.get_node("Mark")
	root.free()
	return ok


func _beam_scene(type_name: String) -> bool:
	var type := load("res://data/fx/beams/%s.tres" % type_name) as BeamType
	return type.scene.resource_path.ends_with("burning_beam_fx.tscn")


func _scene_mark(path: String, tag: String, height_m: float) -> bool:
	var mark := (load(path) as PackedScene).instantiate() as ScarMark
	var ok := _is_mark(mark, tag, height_m)
	mark.free()
	return ok


func _child_mark(path: String, child: String, tag: String, height_m: float) -> bool:
	var root := (load(path) as PackedScene).instantiate()
	var ok := _is_mark(root.get_node(child) as ScarMark, tag, height_m)
	root.free()
	return ok


func _is_mark(mark: ScarMark, tag: String, height_m: float) -> bool:
	return mark != null and mark.texture != null and mark.texture.resource_path == SCARS_DIR + tag + ".png" and is_equal_approx(mark.max_height_m, height_m)


func _result(checks: Dictionary) -> Dictionary:
	var failed := PackedStringArray()
	for key in checks:
		if not checks[key]:
			failed.append(str(key))
	return {"ok": failed.is_empty(), "failed": failed}


static func _same(tiles: Array[Vector2i], expected: Array) -> bool:
	if tiles.size() != expected.size():
		return false
	for i in tiles.size():
		if tiles[i] != expected[i]:
			return false
	return true


## The list a peer back from a drop paints again (GroundScarsNet): in order, the newest `limit` only, the same pictures and
## points after the trip, and nothing that is not an imported texture (a picture made in code, a path from a peer that is not one).
func _record() -> Dictionary:
	var blud := load(SCARS_DIR + "blud.png") as Texture2D
	var scar := load(SCARS_DIR + "scar.png") as Texture2D
	var record := GroundScarRecord.new()
	record.limit = 2
	record.add(scar, Vector3(1.0, 2.0, 3.0), 0.0)
	record.add(blud, Vector3(4.0, 5.0, 6.0), 4.0)
	record.add(scar, Vector3(7.0, 8.0, 9.0), 2.5)
	record.add(ImageTexture.create_from_image(Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)), Vector3.ZERO, 0.0)
	var wire := record.to_wire()
	var back := GroundScarRecord.entries(wire)
	var checks := {}
	checks["newest_kept"] = record.size() == 2 and GroundScarRecord.count(wire) == 2
	checks["same_after_trip"] = back.size() == 2 and back[0][0] == blud and back[0][1] == Vector3(4.0, 5.0, 6.0) \
			and is_equal_approx(back[0][2], 4.0) and back[1][0] == scar and back[1][1] == Vector3(7.0, 8.0, 9.0)
	var bad := {GroundScarRecord.PATHS: PackedStringArray(["res://project.godot"]), GroundScarRecord.MARKS: PackedFloat32Array([0, 1, 2, 3, 0])}
	checks["foreign_path_skipped"] = GroundScarRecord.entries(bad).is_empty() and GroundScarRecord.entries({}).is_empty()
	record.clear()
	checks["cleared"] = record.size() == 0
	return {"ok": not checks.values().has(false), "checks": checks}


## A peer back from a drop while rocks fly (the 060s bug: host 130 marks, the peer 65). The donor's list leaves, then rocks the
## peer never saw land on the donor only and are passed on; rocks both of them see land in either order; two marks the donor
## really has at one place stay two. At the end the peer holds what the donor holds, mark for mark.
func _catch_up() -> Dictionary:
	var scar := load(SCARS_DIR + "scar.png") as Texture2D
	var crack := load(SCARS_DIR + "gscr.png") as Texture2D
	var donor := GroundScarRecord.new()
	var peer := GroundScarRecord.new()
	var passed: Array[Dictionary] = []
	donor.added.connect(func(path: String, at: Vector3, h: float, ordinal: int) -> void:
		passed.append(GroundScarRecord.one(path, at, h, ordinal)))
	donor.add(scar, Vector3(10.0, 0.0, 10.0), 0.0)
	donor.add(crack, Vector3(12.0, 0.0, 10.0), 2.0)
	donor.add(crack, Vector3(12.0, 0.0, 10.0), 2.0)  # two rocks on one spot: two marks
	_own(peer, scar, Vector3(30.0, 0.0, 30.0))  # an effect the peer saw as its world got ready...
	donor.add(scar, Vector3(30.0, 0.0, 30.0), 0.0)  # ...that the donor has too
	var snapshot := donor.to_wire()
	passed.clear()
	var checks := {}
	peer.begin_catch_up()
	_give(peer, snapshot)
	checks["list_merged"] = peer.size() == 4
	donor.add(crack, Vector3(14.0, 0.0, 11.0), 2.0)  # a rock the peer never saw lands
	_give(peer, passed.pop_front())
	checks["late_rock_kept"] = peer.size() == 5
	_own(peer, crack, Vector3(15.0, 0.0, 12.0))  # a rock both see: the peer's lands first
	donor.add(crack, Vector3(15.0, 0.0, 12.0), 2.0)
	_give(peer, passed.pop_front())
	donor.add(crack, Vector3(16.0, 0.0, 13.0), 2.0)  # the donor's lands first
	_give(peer, passed.pop_front())
	_own(peer, crack, Vector3(16.0, 0.0, 13.0))
	checks["shared_rocks_once"] = peer.size() == 7
	peer.end_catch_up()
	_own(peer, scar, Vector3(40.0, 0.0, 40.0))
	donor.add(scar, Vector3(40.0, 0.0, 40.0), 0.0)
	checks["after_done_own_only"] = passed.size() == 1 and peer.merge == null
	checks["same_as_donor"] = peer.size() == donor.size() and _places(peer) == _places(donor)
	return {"ok": not checks.values().has(false), "checks": checks, "donor": donor.size(), "peer": peer.size()}


static func _own(record: GroundScarRecord, texture: Texture2D, at: Vector3) -> void:
	if record.merge == null or record.merge.own_copies(texture.resource_path, at) > 0:
		record.add(texture, at, 0.0)


static func _give(record: GroundScarRecord, wire: Dictionary) -> void:
	for entry: Array in GroundScarRecord.entries(wire):
		var texture := entry[0] as Texture2D
		for i in record.merge.given_copies(texture.resource_path, entry[1], entry[3]):
			record.add(texture, entry[1], entry[2])


static func _places(record: GroundScarRecord) -> Array:
	var out: Array = []
	for entry: Array in GroundScarRecord.entries(record.to_wire()):
		out.append(GroundScarRecord.key_of((entry[0] as Texture2D).resource_path, entry[1]))
	out.sort()
	return out
