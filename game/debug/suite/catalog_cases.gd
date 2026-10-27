extends SceneTree

## RFC-040 040b: the catalog is valid, whatever the balance is. It does NOT compare against the original JSON: changing
## a number in a data/catalog/<folder>/<tag>.tres is allowed. It checks that the content is coherent.
##   - every file is a type of its folder, named after its tag (a case-only repeat gets _2, _3...); wizards only need a unique tag and a snake_case file name
##   - no duplicate tags in a folder
##   - every tag that abilities mention exists
##   - every god (RFC-042) has theme, look and a typed book whose rows are files of the catalog, and no AI profile
##   - every creature and wizard has a complete body scene (a BodyFrame)
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
## Property -> minimum, per type. A strict minimum (">") is a key ending in ">".
const CREATURE_RANGES := {
	"health>": 0, "regeneration_per_s": 0, "drain": 0, "run_speed_m_s": 0, "fly_speed_m_s": 0, "melee_strength": 0,
	"melee_accuracy": 0, "melee_evasion": 0, "ranged_accuracy": 0, "aggressiveness": 0, "vision_m": 0,
	"melee_resistance": 0, "direct_spell_resistance": 0, "splash_spell_resistance": 0, "direct_ranged_resistance": 0,
	"splash_ranged_resistance": 0, "mana": 0, "mana_cost": 0, "souls": 0, "cooldown_s": 0, "casting_time_s": 0,
}
const SPELL_RANGES := {
	"mana_cost": 0, "cast_range_m": 0, "cooldown_s": 0, "casting_time_s": 0, "speed_m_s": 0, "damage_range_m": 0,
	"effect_range_m": 0, "duration_s": 0,
}
const WIZARD_RANGES := {
	"health>": 0, "mana": 0, "run_speed_m_s": 0, "regeneration_per_s": 0, "melee_resistance": 0,
	"direct_spell_resistance": 0, "splash_spell_resistance": 0, "direct_ranged_resistance": 0,
	"splash_ranged_resistance": 0,
}
const BUILDING_RANGES := {"max_health": 0}

var _failures := 0
var _catalog: GameCatalog


func _initialize() -> void:
	_catalog = GameCatalog.shared(true)
	var tables := {
		"creatures": _catalog.creatures, "spells": _catalog.spells, "wizards": _catalog.wizards,
		"abilities": _catalog.abilities, "buildings": _catalog.buildings,
	}
	var tags := {}
	for folder: String in tables:
		tags[folder] = _check_folder(folder, tables[folder])
	_check_ranges("creatures", _catalog.creatures, CREATURE_RANGES)
	_check_ranges("spells", _catalog.spells, SPELL_RANGES)
	_check_ranges("abilities", _catalog.abilities, SPELL_RANGES)
	_check_ranges("wizards", _catalog.wizards, WIZARD_RANGES)
	_check_ranges("buildings", _catalog.buildings, BUILDING_RANGES)
	_check_references(tags)
	_check_gods(tags)
	_check_lobby()
	_check_bodies(tags)
	_check_maps_and_modes()
	_check_audio()
	print("CATALOG creatures %d spells %d wizards %d abilities %d buildings %d body sizes %d gods %d" % [
		_catalog.creatures.size(), _catalog.spells.size(), _catalog.wizards.size(), _catalog.abilities.size(),
		_catalog.buildings.size(), _body_scenes(), _catalog.gods.size()])
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
		if folder == "buildings" and (type as BuildingType).scene() == null:
			_report("buildings/%s: no scene of parts" % file)
		var base: String = type.tag.validate_filename()
		var stem: String = file.get_basename()
		if folder == "wizards" or folder == "creatures":
			# Wizards and creatures have human file names (jadugarr.tres, tag cwa0; trogg.tres, tag ycro): the id is the tag field, the file only has to be snake_case.
			if not _is_snake_case(stem):
				_report("%s/%s: the file name should be snake_case (a-z, 0-9, _)" % [folder, file])
		elif folder != "buildings" and stem != base and not _is_case_repeat(stem, base):
			_report("%s/%s: tag = \"%s\", the file should be %s.tres" % [folder, file, type.tag, base])
	var tags := {}
	for tag: String in seen:
		tags[tag] = true
	return tags


## True for names like "the_ragman": lower-case letters, digits and underscores, starting with a letter.
func _is_snake_case(text: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]*$")
	return pattern.search(text) != null


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
		# 055c1-b: the three slots are references, so they cannot dangle; they must be in the catalog all the same (not a loose copy).
		for slot: AbilityType in creature.abilities():
			if not abilities.has(slot.tag):
				_report("creatures/%s: the ability \"%s\" is not in data/catalog/abilities/" % [_file(creature), slot.tag])
		if creature.is_ranged() != (creature.ranged_attack != null):
			_report("creatures/%s: is_ranged() disagrees with ranged_attack" % _file(creature))
		for passive: CreaturePassive in creature.passives:
			if passive == null:
				_report("creatures/%s: an empty entry in passives" % _file(creature))
			elif passive is DeathCloudType and ((passive as DeathCloudType).ability == null or not abilities.has((passive as DeathCloudType).ability.tag)):
				_report("creatures/%s: a death cloud without an ability of the catalog" % _file(creature))
			elif passive is OnHitPassiveType and ((passive as OnHitPassiveType).spell == null or not spells.has((passive as OnHitPassiveType).spell.tag)):
				_report("creatures/%s: an on-hit passive without a spell of the catalog" % _file(creature))


## 055i-a: the menu lists what is `offered`, the wire carries `id()`, and the «Contra la IA» seat holds real references.
func _check_lobby() -> void:
	if _catalog.offered_wizards().is_empty():
		_report("wizards/: none is offered to the lobby")
	if _catalog.offered_gods().is_empty():
		_report("gods/: none is offered to the lobby")
	for god in _catalog.gods:
		if god.id().is_empty() or _catalog.god(god.id()) != god:
			_report("gods/%s: id() \"%s\" does not find the god back" % [_file(god), god.id()])
	for wizard in _catalog.wizards:
		if wizard.id().is_empty() or _catalog.wizard(wizard.id()) != wizard:
			_report("wizards/%s: id() \"%s\" does not find the wizard back" % [_file(wizard), wizard.id()])
	for creature in _catalog.creatures:
		if creature.id().is_empty() or _catalog.creature(creature.id()) != creature:
			_report("creatures/%s: id() \"%s\" does not find the creature back" % [_file(creature), creature.id()])
		# 055c1: the file carries the human name its sound set already has (ycro.tres is trogg.tres, as is data/audio/creatures/trogg.tres).
		var voice := BodyLook.sounds_in(BodyLook.of_body(creature.body))
		if voice != null and voice.resource_path.begins_with("res://data/audio/creatures/") and voice.resource_path.get_file() != _file(creature):
			_report("creatures/%s: the sound set is %s, the file should have the same name" % [_file(creature), voice.resource_path.get_file()])
	var seat := load("res://data/ai/seat_vs_ai.tres") as AiSeat
	if seat == null or seat.wizard == null:
		_report("data/ai/seat_vs_ai.tres: the seat of «Contra la IA» has no wizard")
	var pick := MatchWire.decode_pick({"wizard": "cwa0", "god": "james"}, true)
	if pick == null or MatchWire.encode_pick(pick) != {"wizard": "cwa0", "model": "jnwr", "god": "james"}:
		_report("MatchWire: the pick cwa0/james does not travel as {wizard, model, god}")


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
		_check_god_look(file, god)
		if god.cast_fx != null and god.cast_fx.resource_path.is_empty():
			_report("gods/%s: cast_fx is embedded (it needs its own file in data/fx to travel)" % file)
		## 055f f4: how the AI plays is its seat's and its difficulty's (data/ai/tactics_*.tres), never the god's
		if "ai_profile" in god:
			_report("gods/%s: still has an ai_profile" % file)
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
			if type.get("icon") == null:
				_report("gods/%s: book.%s \"%s\" has no icon (the book would write its name; tools/bake/fill_type_icons.gd)" % [file, list, tag])
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


## The look is the god's own file (data/look/<tag>.tres) and brings a sky, a light and a glow.
func _check_god_look(file: String, god: GodType) -> void:
	if god.look == null:
		_report("gods/%s: no look" % file)
	elif god.look.resource_path.get_file() != god.tag + ".tres":
		_report("gods/%s: the look \"%s\" is not named after \"%s\"" % [file, god.look.resource_path, god.tag])
	elif god.look.sky == null or god.look.sky.material == null or god.look.light == null or god.look.glow == null:
		_report("gods/%s: the look lacks its sky material, light or glow" % file)


## The catalog's own type of a tag, to tell a book that points to the catalog file from one holding a stray copy.
func _catalog_type(folder: String, tag: String) -> Resource:
	for type: Resource in (_catalog.creatures if folder == "creatures" else _catalog.spells):
		if type.tag == tag:
			return type
	return null


func _check_bodies(tags: Dictionary) -> void:
	for creature: CreatureType in _catalog.creatures:
		if not BodyFacts.of(creature.body).from_scene:
			_report("creatures/%s: no complete body scene (a BodyFrame with Capsule, Footprint, Reach, Center and Top)" % _file(creature))
		_check_custom_model(creature)
	for wizard: WizardType in _catalog.wizards:
		if not BodyFacts.of(wizard.body).from_scene:
			_report("wizards/%s: no complete body scene (a BodyFrame with Capsule, Footprint, Reach, Center and Top)" % _file(wizard))


## How many creatures and wizards wear a body scene (the number the line "body sizes" prints).
func _body_scenes() -> int:
	var count := 0
	for creature: CreatureType in _catalog.creatures:
		count += 1 if creature.body != null else 0
	for wizard: WizardType in _catalog.wizards:
		count += 1 if wizard.body != null else 0
	return count


## RFC-051: a creature whose model is a .glb of assets/custom/models/ has its model scene, and every clip of its library is a
## clip of that .glb (the library is made by tools/bake/new_creature.gd; `--sync` refreshes it after a new export).
func _check_custom_model(creature: CreatureType) -> void:
	var glb_path := "res://assets/custom/models/%s.glb" % creature.model_id()
	if creature.model_id().is_empty() or not ResourceLoader.exists(glb_path):
		return
	if not ModelPaths.exists(creature.model_id()):
		_report("creatures/%s: model \"%s\" has no scenes/bodies/models/%s.tscn (tools/bake/new_creature.gd makes it)" % [_file(creature), creature.model_id(), creature.model_id()])
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
	if creature.clips == null:
		_report("creatures/%s: no clips (run new_creature.gd --sync %s)" % [_file(creature), creature.model_id()])
	else:
		for role in creature.clips.get_animation_list():
			var tag := creature.clips.get_animation(role).resource_name
			if not tag.is_empty() and not player.has_animation(tag):
				_report("creatures/%s: the clip \"%s\" of the role %s is not in %s.glb (run new_creature.gd --sync %s)" % [
					_file(creature), tag, role, creature.model_id(), creature.model_id()])
		if not creature.clips.has_animation(&"idle"):
			_report("creatures/%s: no idle role in its clips (a custom creature needs an idle clip)" % _file(creature))
	if creature.icon == null:
		print("CATALOG warning: creatures/%s has no HUD icon (CreatureType.icon; tools/bake/fill_type_icons.gd or creature_icon.gd fill it)" % _file(creature))
	root.free()


## RFC-049 049d (F293): maps against modes. The starts are counted in the SceneState of the map scene (no instancing: this runs
## without autoloads), as the nodes that instance player_start.tscn, with their `slot` (1 when the scene leaves the default).
func _check_maps_and_modes() -> void:
	var maps := MapCatalog.shared()
	for definition in maps.maps:
		if definition == null:
			continue
		var scene := definition.map_scene
		if scene == null:
			_report("maps/%s: the scene does not load" % definition.tag)
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
