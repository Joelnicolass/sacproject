extends RefCounted

## RFC-055 055o-a: every sound of an FX or of a node of the world is a typed SoundCue, never a text.
## Both gates (it only loads resources; the dedicated server and the room server load all of it too):
## - emitters_typed: in scenes/**/*.tscn every SoundEmitter3D node has `cue = ExtResource(...)` (80 = the 74 emitters of the
##   spells, props and afflictions + the 6 Sound nodes of the FX scenes); none by text, none without a cue.
## - fx_types_sound: 31 ParticleType and 6 BeamType carry a `sound`; the 6 FX scenes of broadcast_scene have a `Sound` child.
## - fx_text_gone: nothing in scenes/ names FxSoundMap, fx_sounds.tres or SoundBus.fx_cue.
## - fx_parity: when tools/migrate/055o_fx_parity.json is there (the one-shot migration's snapshot of how every FX sounded
##   before), each consumer has the same streams and numbers as the cue it used to have. The file goes with the migration.
## 055o-b (bodies):
## - bodies_typed: 67 of the 72 CreatureType and the 15 WizardType have `sounds` (the 5 without are the same ones that had no set);
##   unit.tscn carries `UnitSounds.summon`; every creature set has the melee `fallback`.
## - bodies_text_gone: scenes/audio/ names no SoundLibrary.creature/wizard, no `shared_set` and no `aliases`.
## - bodies_parity: when tools/migrate/055o_bodies_parity.json is there (how every creature and wizard sounded before the
##   migration, event by event), `BodySounds.resolve` gives the same streams and numbers. The file goes with the migration.
## 055o-d (UI):
## - ui_typed: sound_bus.tscn's UiClickSounds has `click`, spell_slot.tscn carries the cue as its `ui_sound` data and the
##   MenuSounds of radial_menu.tscn has its three cues.
## - ui_text_gone: scenes/ names no ui_set, ui_click_key, ui_cue_for nor SoundBus.META_*, and no scene gives `ui_sound` as a key.
## - ui_parity: when tools/migrate/055o_ui_parity.json is there (how every UI event sounded before), each one has the same
##   streams and numbers, the same cue file and the same log event. The file goes with the migration.
## Open gate only:
## - soul_mole_replicated: the Soul Mole's sound of taking the soul plays from the carrier's replicated phase (LEAVING), the
##   state a client of a dedicated server has, not from `reached`, which only the server emits.
## Prints `SOUND REFS typed=<n> text=<m> null=<k> parity=<p>/<q>`, `SOUND REFS bodies creatures=<a>/<b> wizards=<c>/<d> parity=<p>/<q>`
## and `SOUND REFS ui click=<bool> slot=<bool> menu=<n>/3 parity=<p>/<q>`.

const EMITTER_SCENE := "res://scenes/audio/sound_emitter_3d.tscn"
const EMITTER_SCENES: PackedStringArray = [
	"res://scenes/audio/sound_emitter_3d.tscn",
	"res://scenes/spells/zones/zone_sound.tscn",
	"res://scenes/spells/wards/ward_sound.tscn",
]
const FX_SCENES: PackedStringArray = [
	"res://scenes/fx/spike_field.tscn",
	"res://scenes/fx/quake_ring.tscn",
	"res://scenes/fx/wall_spike.tscn",
	"res://scenes/spells/zones/explosion_burst.tscn",
	"res://scenes/spells/zones/ice_shatter.tscn",
	"res://scenes/spells/zones/erupt_burst.tscn",
]
const CUES_DIR := "res://data/audio/cues/"
const PARITY_JSON := "res://tools/migrate/055o_fx_parity.json"
const MATCH_REFS := "res://debug/audio/match_refs_cases.gd"
const EXPECTED_TYPED := 80
const EXPECTED_PARTICLES := 31
const EXPECTED_BEAMS := 6
const BODIES_JSON := "res://tools/migrate/055o_bodies_parity.json"
const CREATURES_DIR := "res://data/catalog/creatures/"
const WIZARDS_DIR := "res://data/catalog/wizards/"
const UNIT_SCENE := "res://scenes/units/unit.tscn"
const EXPECTED_CREATURES := 72
const EXPECTED_CREATURE_SETS := 67
const EXPECTED_WIZARDS := 15
const UI_JSON := "res://tools/migrate/055o_ui_parity.json"
const BUS_SCENE := "res://scenes/audio/sound_bus.tscn"
const SLOT_SCENE := "res://scenes/ui/spell_book/spell_slot.tscn"
const RADIAL_SCENE := "res://scenes/ui/radial/radial_menu.tscn"
## The event a UI log entry carries -> the MenuSounds moment that plays it.
const MENU_MOMENTS := {"menu_open": &"opened", "click": &"chosen", "menu_back": &"cancelled"}


func run(host: Node, open: bool) -> Dictionary:
	var results := {}
	var scan := scan_emitters()
	results["emitters_typed"] = {"ok": int(scan["typed"]) == EXPECTED_TYPED and int(scan["text"]) == 0 and int(scan["null"]) == 0,
		"scan": scan}
	var types := count_fx_types()
	results["fx_types_sound"] = {"ok": int(types["particles"]) == EXPECTED_PARTICLES and int(types["beams"]) == EXPECTED_BEAMS \
		and int(types["scenes"]) == FX_SCENES.size(), "types": types}
	var stale := stale_references()
	results["fx_text_gone"] = {"ok": stale.is_empty(), "found": stale}
	var parity := parity_report(PARITY_JSON)
	results["fx_parity"] = {"ok": (parity["failures"] as PackedStringArray).is_empty(), "parity": parity}
	print("SOUND REFS typed=%d text=%d null=%d parity=%d/%d" % [int(scan["typed"]), int(scan["text"]), int(scan["null"]),
		int(parity["passed"]), int(parity["total"])])
	var bodies := count_body_sets()
	results["bodies_typed"] = {"ok": int(bodies["creatures"]) == EXPECTED_CREATURES and int(bodies["creature_sets"]) == EXPECTED_CREATURE_SETS \
		and int(bodies["wizards"]) == EXPECTED_WIZARDS and int(bodies["wizard_sets"]) == EXPECTED_WIZARDS \
		and bool(bodies["summon"]) and int(bodies["without_fallback"]) == 0, "bodies": bodies}
	var body_stale := stale_body_references()
	results["bodies_text_gone"] = {"ok": body_stale.is_empty(), "found": body_stale}
	var body_parity := bodies_parity_report(BODIES_JSON)
	results["bodies_parity"] = {"ok": (body_parity["failures"] as PackedStringArray).is_empty(), "parity": body_parity}
	print("SOUND REFS bodies creatures=%d/%d wizards=%d/%d parity=%d/%d" % [int(bodies["creature_sets"]), int(bodies["creatures"]),
		int(bodies["wizard_sets"]), int(bodies["wizards"]), int(body_parity["passed"]), int(body_parity["total"])])
	results.merge((load(MATCH_REFS) as GDScript).new().run_match())
	var ui := count_ui_cues()
	results["ui_typed"] = {"ok": bool(ui["click"]) and bool(ui["slot"]) and int(ui["menu"]) == 3, "ui": ui}
	var ui_stale := stale_ui_references()
	results["ui_text_gone"] = {"ok": ui_stale.is_empty(), "found": ui_stale}
	var ui_parity := ui_parity_report(UI_JSON)
	results["ui_parity"] = {"ok": (ui_parity["failures"] as PackedStringArray).is_empty(), "parity": ui_parity}
	print("SOUND REFS ui click=%s slot=%s menu=%d/3 parity=%d/%d" % [ui["click"], ui["slot"], int(ui["menu"]),
		int(ui_parity["passed"]), int(ui_parity["total"])])
	if open and SoundBus.is_active():
		results["soul_mole_replicated"] = await _soul_mole(host)
	return results


## Counts the `cue =` lines of every scene and the emitter nodes that have none: {typed, text, null}.
func scan_emitters() -> Dictionary:
	var totals := {"typed": 0, "text": 0, "null": 0}
	var files := PackedStringArray()
	_files("res://scenes", ".tscn", files)
	var ext_re := RegEx.new()
	ext_re.compile('path="([^"]+)"[^\\]]*id="([^"]+)"')
	var instance_re := RegEx.new()
	instance_re.compile('instance=ExtResource\\("([^"]+)"\\)')
	for path in files:
		var body := FileAccess.get_file_as_string(path)
		if not body.contains("cue = "):
			continue
		var emitter_ids := {}
		var in_emitter := false
		var has_cue := false
		for line in body.split("\n"):
			if line.begins_with("[ext_resource"):
				var found := ext_re.search(line)
				if found != null and EMITTER_SCENES.has(found.get_string(1)):
					emitter_ids[found.get_string(2)] = true
			elif line.begins_with("["):
				if in_emitter and not has_cue:
					totals["null"] += 1
				in_emitter = false
				has_cue = false
				if line.begins_with("[node ") and line.contains(' parent="'):
					var inst := instance_re.search(line)
					in_emitter = inst != null and emitter_ids.has(inst.get_string(1))
			elif line.begins_with("cue = ExtResource"):
				totals["typed"] += 1
				has_cue = true
			elif line.begins_with('cue = &"'):
				totals["text"] += 1
				has_cue = true
		if in_emitter and not has_cue:
			totals["null"] += 1
	return totals


## ParticleType and BeamType with a `sound` under data/fx, and the FX scenes whose `Sound` child has a cue.
func count_fx_types() -> Dictionary:
	var counts := {"particles": 0, "beams": 0, "scenes": 0}
	var files := PackedStringArray()
	_files("res://data/fx", ".tres", files)
	for path in files:
		var loaded := load(path)
		if loaded is ParticleType and (loaded as ParticleType).sound != null:
			counts["particles"] += 1
		elif loaded is BeamType and (loaded as BeamType).sound != null:
			counts["beams"] += 1
	for path in FX_SCENES:
		var node := _instance(path)
		var sound := node.get_node_or_null("Sound") as SoundEmitter3D if node != null else null
		if sound != null and sound.cue != null:
			counts["scenes"] += 1
		if node != null:
			node.free()
	return counts


## Lines of scenes/ that still name the table of texts this cut removed.
func stale_references() -> PackedStringArray:
	var found := PackedStringArray()
	var files := PackedStringArray()
	_files("res://scenes", ".gd", files)
	_files("res://scenes", ".tscn", files)
	for path in files:
		var body := FileAccess.get_file_as_string(path)
		for needle: String in ["FxSoundMap", "fx_sounds.tres", "fx_cue("]:
			if body.contains(needle):
				found.append("%s: %s" % [path, needle])
	return found


## Compares the snapshot of how every FX sounded before the migration with the typed data: {total, passed, failures}.
## No snapshot file (the migration is over): {total 0, passed 0, failures []}.
func parity_report(json_path: String) -> Dictionary:
	var report := {"total": 0, "passed": 0, "failures": PackedStringArray()}
	if not FileAccess.file_exists(json_path):
		return report
	var snapshot: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not snapshot is Dictionary:
		(report["failures"] as PackedStringArray).append("%s no es un JSON válido" % json_path)
		return report
	var cues: Dictionary = (snapshot as Dictionary).get("cues", {})
	var consumers: Array = (snapshot as Dictionary).get("consumers", [])
	for item: Dictionary in consumers:
		report["total"] += 1
		var name := str(item.get("cue", ""))
		var old: Dictionary = cues.get(name, {})
		var problem := _cue_problem(name, old)
		if problem.is_empty():
			problem = _consumer_problem(item)
		if problem.is_empty():
			report["passed"] += 1
		else:
			(report["failures"] as PackedStringArray).append("%s %s: %s" % [item.get("path", ""), item.get("node", ""), problem])
	return report


## "" when the cue file has the streams and numbers the old one had.
func _cue_problem(name: String, old: Dictionary) -> String:
	var cue := load(CUES_DIR + name + ".tres") as SoundCue
	if cue == null:
		return "falta data/audio/cues/%s.tres" % name
	return cue_problem(cue, old)


## "" when `cue` has the streams and numbers of the snapshot entry `old` ({streams, props}).
func cue_problem(cue: SoundCue, old: Dictionary) -> String:
	var streams := PackedStringArray()
	for stream in cue.streams:
		streams.append(stream.resource_path if stream != null else "")
	var old_streams: Array = old.get("streams", [])
	var wanted := PackedStringArray(old_streams)
	if streams != wanted:
		return "streams %s y eran %s" % [streams, wanted]
	var old_props: Array = old.get("props", [])
	for line: String in old_props:
		var parts := line.split(" = ", true, 1)
		if parts.size() != 2 or parts[0] == "streams":
			continue
		var expected: Variant = str_to_var(parts[1])
		var got: Variant = cue.get(parts[0])
		var same := is_equal_approx(float(got), float(expected)) if (got is float or got is int) and (expected is float or expected is int) \
			else str(got) == str(expected)
		if not same:
			return "%s es %s y era %s" % [parts[0], got, expected]
	return ""


## "" when the consumer of the snapshot points at the cue file it should.
func _consumer_problem(item: Dictionary) -> String:
	var wanted := CUES_DIR + str(item.get("cue", "")) + ".tres"
	var path := "res://" + str(item.get("path", ""))
	var got: SoundCue = null
	var kind := str(item.get("kind", ""))
	if kind == "particle":
		var particle := load(path) as ParticleType
		got = particle.sound if particle != null else null
	elif kind == "beam":
		var beam := load(path) as BeamType
		got = beam.sound if beam != null else null
	else:
		var node := _instance(path)
		var emitter := node.get_node_or_null(NodePath(str(item.get("node", ".")))) as SoundEmitter3D if node != null else null
		got = emitter.cue if emitter != null else null
		if node != null:
			node.free()
	if got == null:
		return "sin cue"
	return "" if got.resource_path == wanted else "cue %s y era %s" % [got.resource_path, wanted]


## How many creatures and wizards of the catalog have `sounds`, whether the creature scene has its summon cue and how many
## creature sets lack the melee fallback: {creatures, creature_sets, wizards, wizard_sets, summon, without_fallback}.
func count_body_sets() -> Dictionary:
	var counts := {"creatures": 0, "creature_sets": 0, "wizards": 0, "wizard_sets": 0, "summon": false, "without_fallback": 0}
	var files := PackedStringArray()
	_files(CREATURES_DIR, ".tres", files)
	for path in files:
		var type := load(path) as CreatureType
		if type == null:
			continue
		counts["creatures"] += 1
		if type.sounds != null:
			counts["creature_sets"] += 1
			if type.sounds.fallback == null:
				counts["without_fallback"] += 1
	files.clear()
	_files(WIZARDS_DIR, ".tres", files)
	for path in files:
		var wizard := load(path) as WizardType
		if wizard == null:
			continue
		counts["wizards"] += 1
		if wizard.sounds != null:
			counts["wizard_sets"] += 1
	counts["summon"] = _unit_summon() != null
	return counts


## Lines of scenes/audio/ that still use what 055o-b removed: the lookup of a body's set by tag, the shared set and the aliases.
func stale_body_references() -> PackedStringArray:
	var found := PackedStringArray()
	var files := PackedStringArray()
	_files("res://scenes/audio", ".gd", files)
	for path in files:
		var body := FileAccess.get_file_as_string(path)
		for needle: String in ["SoundLibrary.creature(", "SoundLibrary.wizard(", "SoundLibrary.type_file(", "shared_set", "aliases"]:
			if body.contains(needle):
				found.append("%s: %s" % [path, needle])
	return found


## The summon cue of unit.tscn's UnitSounds (null when the scene does not carry one).
func _unit_summon() -> SoundCue:
	var unit := _instance(UNIT_SCENE)
	var sounds := unit.get_node_or_null("UnitSounds") as UnitSounds if unit != null else null
	var summon: SoundCue = sounds.summon if sounds != null else null
	if unit != null:
		unit.free()
	return summon


## Compares the snapshot of how every creature and wizard sounded before the migration with `BodySounds.resolve` over the typed
## sets: {total, passed, failures}, one check per (body, event). No snapshot file (the migration is over): total 0.
func bodies_parity_report(json_path: String) -> Dictionary:
	var report := {"total": 0, "passed": 0, "failures": PackedStringArray()}
	if not FileAccess.file_exists(json_path):
		return report
	var snapshot: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not snapshot is Dictionary:
		(report["failures"] as PackedStringArray).append("%s no es un JSON válido" % json_path)
		return report
	var cues: Dictionary = (snapshot as Dictionary).get("cues", {})
	var summon := _unit_summon()
	for item: Dictionary in (snapshot as Dictionary).get("bodies", []):
		var path := "res://" + str(item.get("catalog", ""))
		var is_creature := str(item.get("kind", "")) == "creature"
		var sounds: SoundSet = null
		if is_creature:
			var creature := load(path) as CreatureType
			sounds = creature.sounds if creature != null else null
		else:
			var wizard := load(path) as WizardType
			sounds = wizard.sounds if wizard != null else null
		var events: Dictionary = item.get("events", {})
		for event: String in events:
			report["total"] += 1
			var got := BodySounds.resolve(sounds, StringName(event), summon if is_creature and event == "summon" else null)
			var problem := _body_problem(got, events[event], cues)
			if problem.is_empty():
				report["passed"] += 1
			else:
				(report["failures"] as PackedStringArray).append("%s %s: %s" % [item.get("catalog", ""), event, problem])
	return report


## "" when `got` is the cue the snapshot id `wanted` describes (null for null).
func _body_problem(got: SoundCue, wanted: Variant, cues: Dictionary) -> String:
	if wanted == null:
		return "" if got == null else "suena y no sonaba"
	if got == null:
		return "no suena y sonaba"
	return cue_problem(got, cues.get(str(wanted), {}))


## What the UI scenes carry: {click: UiClickSounds.click is assigned, slot: the slot's `ui_sound` is a cue, menu: how many of the
## three MenuSounds cues are assigned}.
func count_ui_cues() -> Dictionary:
	var counts := {"click": false, "slot": false, "menu": 0}
	var bus := _instance(BUS_SCENE)
	var clicks := bus.get_node_or_null("UiClickSounds") as UiClickSounds if bus != null else null
	counts["click"] = clicks != null and clicks.click != null
	if bus != null:
		bus.free()
	var slot := _instance(SLOT_SCENE)
	counts["slot"] = slot != null and slot.get_meta(UiClickSounds.META_UI_SOUND, null) is SoundCue
	if slot != null:
		slot.free()
	var sounds := _menu_sounds()
	if sounds != null:
		for cue: SoundCue in [sounds.opened, sounds.chosen, sounds.cancelled]:
			counts["menu"] += 1 if cue != null else 0
		sounds.owner.free()
	return counts


## The MenuSounds of a fresh radial menu (its owner, the menu, is the one to free), or null.
func _menu_sounds() -> MenuSounds:
	var radial := _instance(RADIAL_SCENE)
	var sounds := radial.get_node_or_null("MenuSounds") as MenuSounds if radial != null else null
	if sounds == null and radial != null:
		radial.free()
	return sounds


## Lines of scenes/ that still use what 055o-d removed: the UI set by key on SoundBus and the key-valued `ui_sound` data.
func stale_ui_references() -> PackedStringArray:
	var found := PackedStringArray()
	var files := PackedStringArray()
	_files("res://scenes", ".gd", files)
	_files("res://scenes", ".tscn", files)
	for path in files:
		var body := FileAccess.get_file_as_string(path)
		for needle: String in ["ui_set", "ui_click_key", "ui_cue_for", "SoundBus.META_", "metadata/ui_sound = &", "ui.tres"]:
			if body.contains(needle):
				found.append("%s: %s" % [path, needle])
	return found


## Compares the snapshot of how every UI event sounded before the migration with the typed data: {total, passed, failures}.
## No snapshot file (the migration is over): total 0.
func ui_parity_report(json_path: String) -> Dictionary:
	var report := {"total": 0, "passed": 0, "failures": PackedStringArray()}
	if not FileAccess.file_exists(json_path):
		return report
	var snapshot: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not snapshot is Dictionary:
		(report["failures"] as PackedStringArray).append("%s no es un JSON válido" % json_path)
		return report
	var cues: Dictionary = (snapshot as Dictionary).get("cues", {})
	for item: Dictionary in (snapshot as Dictionary).get("consumers", []):
		report["total"] += 1
		var name := str(item.get("cue", ""))
		var problem := _cue_problem(name, cues.get(name, {}))
		if problem.is_empty():
			problem = _ui_consumer_problem(item)
		if problem.is_empty():
			report["passed"] += 1
		else:
			(report["failures"] as PackedStringArray).append("%s %s (%s): %s" % [item.get("path", ""), item.get("node", ""),
				item.get("old_key", ""), problem])
	return report


## "" when the UI consumer of the snapshot points at the cue file it should and logs the event it logged.
func _ui_consumer_problem(item: Dictionary) -> String:
	var wanted := CUES_DIR + str(item.get("cue", "")) + ".tres"
	var got: SoundCue = null
	match str(item.get("kind", "")):
		"button":
			var bus := _instance(BUS_SCENE)
			var clicks := bus.get_node_or_null("UiClickSounds") as UiClickSounds if bus != null else null
			got = clicks.click if clicks != null else null
			if bus != null:
				bus.free()
		"button_meta":
			var slot := _instance(SLOT_SCENE)
			var own: Variant = slot.get_meta(UiClickSounds.META_UI_SOUND, null) if slot != null else null
			got = own if own is SoundCue else null
			if slot != null:
				slot.free()
		"menu":
			var sounds := _menu_sounds()
			var event := str(item.get("event", ""))
			if sounds == null or not MENU_MOMENTS.has(event):
				return "sin MenuSounds o evento %s desconocido" % event
			var moment: StringName = MENU_MOMENTS[event]
			got = sounds.cue_for(moment)
			var logged := sounds.event_for(moment)
			sounds.owner.free()
			if str(logged) != event:
				return "el evento es %s y era %s" % [logged, event]
		_:
			return "kind desconocido"
	if got == null:
		return "sin cue"
	return "" if got.resource_path == wanted else "cue %s y era %s" % [got.resource_path, wanted]


func _soul_mole(host: Node) -> Dictionary:
	var mole := _instance("res://scenes/spells/carrier/soul_mole.tscn")
	var take := mole.get_node_or_null("TakeCue") as PhaseCue if mole != null else null
	var take_sound := mole.get_node_or_null("TakeSound") as SoundEmitter3D if mole != null else null
	var wired := take != null and take_sound != null and take.phase == SpellCarrier.Phase.LEAVING and take.sound == take_sound \
		and take_sound.cue != null and not take_sound.loop
	if mole != null:
		mole.free()
	var synced := CarrierSync.PROPS_SOUL_TRIP.has(".:phase")
	## Only the replicated phase drives the sound: no `reached`, no SoulTrip.
	SoundBus.stop_all()
	await host.get_tree().process_frame
	var carrier := SpellCarrier.new()
	carrier.name = "CaseMole"
	carrier.process_mode = Node.PROCESS_MODE_DISABLED
	var sound := (load(EMITTER_SCENE) as PackedScene).instantiate() as SoundEmitter3D
	sound.play_on_ready = false
	sound.cue = _cue([load("res://debug/audio/fixtures/beep_a.tres")])
	var phase_cue := PhaseCue.new()
	phase_cue.carrier = carrier
	phase_cue.phase = SpellCarrier.Phase.LEAVING
	phase_cue.sound = sound
	carrier.add_child(sound)
	carrier.add_child(phase_cue)
	host.add_child(carrier)
	SoundBus.sound_log.clear()
	carrier.phase = SpellCarrier.Phase.LEAVING
	var last: Dictionary = SoundBus.sound_log.last()
	var played: bool = SoundBus.sound_log.size() == 1 and last.get("emitter") == &"CaseMole" and last.get("event") == SoundEvent.CAST \
		and bool(last.get("played"))
	carrier.queue_free()
	return {"ok": wired and synced and played, "wired": wired, "phase_replicated": synced, "played_from_phase": played}


func _cue(streams: Array[AudioStream]) -> SoundCue:
	var cue := SoundCue.new()
	cue.streams = streams
	cue.max_voices = 0
	return cue


func _instance(path: String) -> Node:
	var packed := load(path) as PackedScene
	return packed.instantiate() if packed != null else null


static func _files(dir_path: String, suffix: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_files(dir_path.path_join(sub), suffix, out)
	for file in dir.get_files():
		if file.ends_with(suffix):
			out.append(dir_path.path_join(file))
