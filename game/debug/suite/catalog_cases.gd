extends SceneTree

## RFC-040 040b: the catalog is valid, whatever the balance is. It does NOT compare against the original JSON: changing
## a number in a data/catalog/<folder>/<tag>.tres is allowed. It checks that the content is coherent.
##   - every file is a type of its folder, named after its tag (a case-only repeat gets _2, _3...)
##   - no duplicate tags in a folder
##   - every tag that abilities mention exists
##   - every god (RFC-042) has theme, look, AI profile and a typed book whose rows are files of the catalog
##   - every creature and wizard has its BodySize
##   - the numbers are sane (health > 0, costs >= 0, ...)
##   - (RFC-049 049d) every map has as many PlayerStart (slots 1..N, no repeats) as its `player_starts`, and every mode has
##     teams 0..T-1 without gaps and a map with `player_starts >= seats`; a mode no room map can host is only a warning
##   - (RFC-052 052b) every sound set of data/audio/ names files that exist; a set of your own (data/audio/custom/) never
##     names the original's audio (assets/original/, data/audio/original/). Without the original's import
##     (assets/original/audio/index.json) its files are not checked, only counted.
## Failures name the file: "creatures/xyz.tres: health = -5". Prints CATALOG PASS or CATALOG FAIL.
## "$GODOT" --headless --path game --script res://debug/suite/catalog_cases.gd
## No autoloads: the catalog is read through GameCatalog, the same scan the game does.

const MAX_REPORTED := 60
## References the original data itself leaves dangling ("tsg@" is in no table of the original game).
const KNOWN_DANGLING: PackedStringArray = ["tsg@"]
## Property -> minimum, per type. A strict minimum (">") is a key ending in ">".
const CREATURE_RANGES := {
	"health>": 0, "regeneration_per_s": 0, "drain": 0, "running_speed": 0, "flying_speed": 0, "melee_strength": 0,
	"melee_accuracy": 0, "melee_evasion": 0, "ranged_accuracy": 0, "aggressiveness": 0, "sight_range": 0,
	"melee_resistance": 0, "direct_spell_resistance": 0, "splash_spell_resistance": 0, "direct_ranged_resistance": 0,
	"splash_ranged_resistance": 0, "mana": 0, "mana_cost": 0, "souls": 0, "cooldown_s": 0, "casting_time_s": 0,
}
const SPELL_RANGES := {
	"mana_cost": 0, "cast_range": 0, "cooldown_s": 0, "casting_time_s": 0, "speed": 0, "damage_range": 0,
	"effect_range": 0, "duration": 0,
}
const WIZARD_RANGES := {
	"health>": 0, "mana": 0, "running_speed": 0, "regeneration_per_s": 0, "melee_resistance": 0,
	"direct_spell_resistance": 0, "splash_spell_resistance": 0, "direct_ranged_resistance": 0,
	"splash_ranged_resistance": 0,
}
const BUILDING_RANGES := {"max_health": 0}
const BODY_RANGES := {"height": 0, "radius": 0, "reach": 0}

var _failures := 0
var _catalog: GameCatalog


func _initialize() -> void:
	_catalog = GameCatalog.shared(true)
	var tables := {
		"creatures": _catalog.creatures, "spells": _catalog.spells, "wizards": _catalog.wizards,
		"abilities": _catalog.abilities, "buildings": _catalog.buildings, "body_sizes": _catalog.body_sizes,
	}
	var tags := {}
	for folder: String in tables:
		tags[folder] = _check_folder(folder, tables[folder])
	_check_ranges("creatures", _catalog.creatures, CREATURE_RANGES)
	_check_ranges("spells", _catalog.spells, SPELL_RANGES)
	_check_ranges("abilities", _catalog.abilities, SPELL_RANGES)
	_check_ranges("wizards", _catalog.wizards, WIZARD_RANGES)
	_check_ranges("buildings", _catalog.buildings, BUILDING_RANGES)
	_check_ranges("body_sizes", _catalog.body_sizes, BODY_RANGES)
	_check_references(tags)
	_check_gods(tags)
	_check_bodies(tags)
	_check_maps_and_modes()
	_check_audio()
	print("CATALOG creatures %d spells %d wizards %d abilities %d buildings %d body sizes %d gods %d" % [
		_catalog.creatures.size(), _catalog.spells.size(), _catalog.wizards.size(), _catalog.abilities.size(),
		_catalog.buildings.size(), _catalog.body_sizes.size(), _catalog.gods.size()])
	print("CATALOG PASS" if _failures == 0 else "CATALOG FAIL (%d problems)" % _failures)
	quit(0 if _failures == 0 else 1)


## Every .tres of the folder is a type of it, named after its tag; no tag twice. Returns {tag: true}.
func _check_folder(folder: String, types: Array) -> Dictionary:
	var files := GameCatalog.files_in(folder)
	if files.size() != types.size():
		_report("%s/: %d .tres files but %d usable types (a file is not a %s)" % [folder, files.size(), types.size(), folder])
	var seen := {}
	for type: Resource in types:
		var file := _file(type)
		if type.tag.is_empty():
			_report("%s/%s: tag is empty" % [folder, file])
			continue
		if seen.has(type.tag):
			_report("%s/%s: duplicate tag \"%s\" (also in %s)" % [folder, file, type.tag, seen[type.tag]])
		seen[type.tag] = file
		var base: String = type.tag.validate_filename()
		var stem: String = file.get_basename()
		if stem != base and not _is_case_repeat(stem, base):
			_report("%s/%s: tag = \"%s\", the file should be %s.tres" % [folder, file, type.tag, base])
	var tags := {}
	for tag: String in seen:
		tags[tag] = true
	return tags


## "name_2", "name_3"... for a tag whose lower-case form is already taken in the folder (macOS file names).
func _is_case_repeat(stem: String, base: String) -> bool:
	var at := stem.rfind("_")
	return at > 0 and stem.substr(0, at) == base and stem.substr(at + 1).is_valid_int()


func _check_ranges(folder: String, types: Array, ranges: Dictionary) -> void:
	for type: Resource in types:
		for key: String in ranges:
			var strict := key.ends_with(">")
			var property := key.trim_suffix(">")
			var value: float = type.get(property)
			if value < ranges[key] or (strict and value <= ranges[key]):
				_report("%s/%s: %s = %s" % [folder, _file(type), property, str(type.get(property))])


func _check_references(tags: Dictionary) -> void:
	var abilities: Dictionary = tags["abilities"]
	var spells: Dictionary = tags["spells"]
	for creature: CreatureType in _catalog.creatures:
		var names := {"ranged_attack_tag": [creature.ranged_attack_tag], "active_ability_tag": [creature.active_ability_tag],
				"passive_on_damage": [creature.passive_on_damage], "ability_tags": Array(creature.ability_tags),
				"passive_abilities": Array(creature.passive_abilities)}
		for property: String in names:
			for tag: String in names[property]:
				# A passive may also be a spell (eniv, zerf).
				if not tag.is_empty() and not abilities.has(tag) and not spells.has(tag) and not KNOWN_DANGLING.has(tag):
					_report("creatures/%s: %s = \"%s\" is not an ability or a spell" % [_file(creature), property, tag])


func _check_gods(tags: Dictionary) -> void:
	if _catalog.gods.is_empty():
		_report("gods/: no gods (missing or empty)")
		return
	var seen := {}
	for god in _catalog.gods:
		var file := god.resource_path.get_file()
		if god.tag.is_empty() or file != god.tag + ".tres":
			_report("gods/%s: the file is not named after the tag \"%s\"" % [file, god.tag])
		if seen.has(god.tag):
			_report("gods/%s: the tag \"%s\" is repeated" % [file, god.tag])
		seen[god.tag] = true
		if god.display_name.is_empty():
			_report("gods/%s: no display_name" % file)
		_check_god_file(file, "theme", god.theme_path, god.tag)
		_check_god_file(file, "look", god.look_path, god.tag)
		if not god.cast_fx_path.is_empty() and not ResourceLoader.exists(god.cast_fx_path):
			_report("gods/%s: cast_fx_path \"%s\" does not exist" % [file, god.cast_fx_path])
		if god.ai_profile == null:
			_report("gods/%s: no ai_profile" % file)
		elif str(god.ai_profile.god) != god.tag:
			_report("gods/%s: the ai_profile is of \"%s\"" % [file, god.ai_profile.god])
		if god.book == null:
			_report("gods/%s: no book" % file)
			continue
		_check_book(file, god.book, tags)


func _check_book(file: String, book: GodBook, tags: Dictionary) -> void:
	var lists := {"creatures": [book.creatures, "creatures"], "spells": [book.spells, "spells"], "structures": [book.structures, "spells"]}
	for list: String in lists:
		var seen := {}
		for type: Resource in lists[list][0]:
			if type == null:
				_report("gods/%s: book.%s has an empty row" % [file, list])
				continue
			var tag := str(type.get("tag"))
			if not tags[lists[list][1]].has(tag) or type != _catalog_type(lists[list][1], tag):
				_report("gods/%s: book.%s has \"%s\", which is not a file of %s/" % [file, list, tag, lists[list][1]])
			if seen.has(tag):
				_report("gods/%s: book.%s repeats \"%s\"" % [file, list, tag])
			seen[tag] = true
	var unlocked := {}
	for unlock in book.unlocks:
		if unlock == null or unlock.type == null:
			_report("gods/%s: book.unlocks has an empty line" % file)
			continue
		var tag := unlock.tag()
		var folder := "creatures" if unlock.type is CreatureType else "spells"
		if not tags[folder].has(tag) or unlock.type != _catalog_type(folder, tag):
			_report("gods/%s: book.unlocks has \"%s\", which is no creature or spell of the catalog" % [file, tag])
		if unlocked.has(tag):
			_report("gods/%s: book.unlocks repeats \"%s\"" % [file, tag])
		unlocked[tag] = true
		if unlock.level < 0 or unlock.level > 9:
			_report("gods/%s: book.unlocks[%s] = %d" % [file, tag, unlock.level])


## The theme or look file exists and is of this god (read as text: loading it would load the biome's textures).
func _check_god_file(file: String, what: String, path: String, tag: String) -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		_report("gods/%s: %s_path \"%s\" does not exist" % [file, what, path])
		return
	if not FileAccess.get_file_as_string(path).contains('god = &"%s"' % tag):
		_report("gods/%s: %s_path \"%s\" is not of \"%s\"" % [file, what, path, tag])


## The catalog's own type of a tag, to tell a book that points to the catalog file from one holding a stray copy.
func _catalog_type(folder: String, tag: String) -> Resource:
	for type: Resource in (_catalog.creatures if folder == "creatures" else _catalog.spells):
		if type.tag == tag:
			return type
	return null


func _check_bodies(tags: Dictionary) -> void:
	var sizes: Dictionary = tags["body_sizes"]
	for creature: CreatureType in _catalog.creatures:
		if not sizes.has(creature.model):
			_report("creatures/%s: model = \"%s\" has no body_sizes/ file" % [_file(creature), creature.model])
	for creature: CreatureType in _catalog.creatures:
		_check_custom_model(creature)
	for wizard: WizardType in _catalog.wizards:
		if not sizes.has(wizard.model):
			_report("wizards/%s: model = \"%s\" has no body_sizes/ file" % [_file(wizard), wizard.model])
	for size: BodySize in _catalog.body_sizes:
		if not size.box.is_empty() and size.box.size() != 6:
			_report("body_sizes/%s: box has %d numbers, it needs 6" % [_file(size), size.box.size()])
		if not size.upright_fix.is_empty() and size.upright_fix.size() != 3:
			_report("body_sizes/%s: upright_fix has %d numbers, it needs 3" % [_file(size), size.upright_fix.size()])


## RFC-051: a creature whose model is a .glb of assets/custom/models/ has its model scene, and every clip its fields name is a
## clip of that .glb (the fields are filled by tools/bake/new_creature.gd; `--sync` refreshes them after the scene is edited).
func _check_custom_model(creature: CreatureType) -> void:
	var glb_path := "res://assets/custom/models/%s.glb" % creature.model
	if creature.model.is_empty() or not ResourceLoader.exists(glb_path):
		return
	if not BodyModel.exists(creature.model):
		_report("creatures/%s: model \"%s\" has no scenes/bodies/models/%s.tscn (tools/bake/new_creature.gd makes it)" % [_file(creature), creature.model, creature.model])
		return
	var scene := load(glb_path) as PackedScene
	var root := scene.instantiate() if scene != null else null
	var players: Array = root.find_children("*", "AnimationPlayer", true, false) if root != null else []
	if players.is_empty():
		_report("creatures/%s: %s has no animations" % [_file(creature), glb_path])
		if root != null:
			root.free()
		return
	var player := players[0] as AnimationPlayer
	var clips: Array[Dictionary] = [creature.idle_animation, creature.run_animation, creature.walk_animation]
	clips.append_array(creature.melee_animations)
	clips.append_array(creature.shoot_animations)
	for table: Dictionary in [creature.stun_animations, creature.death_animations, creature.flight_animations,
			creature.captive_animations, creature.extra_animations]:
		for role: String in table:
			clips.append(table[role])
	for clip in clips:
		var tag := str(clip.get("tag", ""))
		if not tag.is_empty() and not player.has_animation(tag):
			_report("creatures/%s: the clip \"%s\" is not in %s.glb (run new_creature.gd --sync %s)" % [_file(creature), tag, creature.model, creature.model])
	if creature.idle_animation.is_empty():
		_report("creatures/%s: no idle_animation (a custom creature needs an idle clip)" % _file(creature))
	# F336: the melee swings are the slots of melee_animations (attack, attack2, attack3 of the model); each lands on a frame of its clip.
	if creature.melee_animations.size() > 3:
		_report("creatures/%s: %d melee_animations, the rules use 3 at most (attack, attack2, attack3)" % [_file(creature), creature.melee_animations.size()])
	for index in creature.melee_animations.size():
		var swing: Dictionary = creature.melee_animations[index]
		var frames := int(swing.get("frames", 0))
		var ticks: Array = swing.get("attack_ticks", [])
		if frames <= 0:
			_report("creatures/%s: melee_animations[%d] has no clip (run new_creature.gd --sync %s)" % [_file(creature), index, creature.model])
		elif ticks.is_empty():
			_report("creatures/%s: melee_animations[%d] (%s) has no attack_ticks (the blow would land on the last frame)" % [_file(creature), index, swing.get("tag", "")])
		else:
			for tick in ticks:
				if float(tick) < 0.0 or float(tick) > float(frames):
					_report("creatures/%s: melee_animations[%d] (%s) lands on frame %s, the clip has %d" % [_file(creature), index, swing.get("tag", ""), tick, frames])
	if creature.icon == null and not ResourceLoader.exists("res://assets/custom/icons/%s.png" % creature.model):
		print("CATALOG warning: creatures/%s has no HUD icon (assets/custom/icons/%s.png or CreatureType.icon; new_creature.gd draws one with a window)" % [_file(creature), creature.model])
	root.free()


## RFC-049 049d (F293): maps against modes. The starts are counted in the SceneState of the map scene (no instancing: this runs
## without autoloads), as the nodes that instance player_start.tscn, with their `slot` (1 when the scene leaves the default).
func _check_maps_and_modes() -> void:
	var maps := MapCatalog.shared()
	for definition in maps.maps:
		if definition == null:
			continue
		var scene := definition.load_scene()
		if scene == null:
			_report("maps/%s: the scene '%s' does not load" % [definition.tag, definition.map_scene_path])
			continue
		var slots := _start_slots(scene.get_state())
		var expected: Array[int] = []
		for slot in range(1, definition.player_starts + 1):
			expected.append(slot)
		var found := slots.duplicate()
		found.sort()
		if found != expected:
			_report("maps/%s: player_starts = %d but the scene has starts in the slots %s" % [definition.tag, definition.player_starts, str(found)])
	var modes := GameModeCatalog.shared()
	for mode in modes.modes:
		if mode == null:
			continue
		if mode.team_of_seat.is_empty():
			_report("modes/%s: no seats" % mode.tag)
			continue
		var teams := {}
		for team in mode.team_of_seat:
			teams[team] = true
		for team in range(teams.size()):
			if not teams.has(team):
				_report("modes/%s: the teams are not 0..T-1 (team %d is missing)" % [mode.tag, team])
				break
		if modes.map_tags_for(mode, maps).is_empty():
			_report("modes/%s: %d seats and no map has that many starts" % [mode.tag, mode.seats()])
		elif mode.room_selectable and modes.map_tags_for(mode, maps, true).is_empty():
			print("CATALOG warning: modes/%s has no map a room can offer (only test maps)" % mode.tag)


## The `slot` of every node of the scene that instances scenes/map/props/player_start.tscn.
func _start_slots(state: SceneState) -> Array[int]:
	var slots: Array[int] = []
	for index in state.get_node_count():
		var instance := state.get_node_instance(index)
		if instance == null or instance.resource_path != "res://scenes/map/props/player_start.tscn":
			continue
		var slot := 1
		for property in state.get_node_property_count(index):
			if state.get_node_property_name(index, property) == &"slot":
				slot = int(state.get_node_property_value(index, property))
		slots.append(slot)
	return slots


const AUDIO_DIR := "res://data/audio/"
const AUDIO_CUSTOM_DIR := "res://data/audio/custom/"
const ORIGINAL_AUDIO := "res://assets/original/audio/"
const ORIGINAL_ONLY: PackedStringArray = ["res://assets/original/", "res://data/audio/original/"]


## RFC-052 052b: the files the sets of data/audio/ reference (read without loading the sets).
func _check_audio() -> void:
	var imported := FileAccess.file_exists(ORIGINAL_AUDIO + "index.json")
	var sets := 0
	var unchecked := 0
	for path in _tres_under(AUDIO_DIR):
		sets += 1
		var own := path.begins_with(AUDIO_CUSTOM_DIR)
		var file := path.trim_prefix(AUDIO_DIR)
		for dep in ResourceDeps.paths(path):
			if dep.is_empty():
				_report("audio/%s: names a uid the project does not know" % file)
				continue
			if dep.begins_with("res://data/audio/original/"):
				_report("audio/%s: names %s (data/audio/original/ no longer exists)" % [file, dep])
			if own:
				for prefix in ORIGINAL_ONLY:
					if dep.begins_with(prefix):
						_report("audio/%s: a set of your own names the original's %s" % [file, dep])
			if dep.begins_with(ORIGINAL_AUDIO) and not imported:
				unchecked += 1
			elif not ResourceLoader.exists(dep):
				_report("audio/%s: %s does not exist" % [file, dep])
	print("CATALOG audio sets %d%s" % [sets, "" if unchecked == 0 else
		" (%d files of the original's audio not checked: assets/original/audio/ is not imported)" % unchecked])


static func _tres_under(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_tres_under(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "tres":
			out.append(dir.path_join(file))
	return out


func _file(type: Resource) -> String:
	return type.resource_path.get_file()


func _report(message: String) -> void:
	_failures += 1
	if _failures <= MAX_REPORTED:
		print("CATALOG problem: " + message)
