extends RefCounted

## RFC-055 055o-a: every sound of an FX or of a node of the world is a typed SoundCue, never a text.
## Both gates (it only loads resources; the dedicated server and the room server load all of it too):
## - emitters_typed: in scenes/**/*.tscn every SoundEmitter3D node has `cue = ExtResource(...)` (80 = the 74 emitters of the
##   spells, props and afflictions + the 6 Sound nodes of the FX scenes); none by text, none without a cue.
## - fx_types_sound: 31 ParticleType and 6 BeamType carry a `sound`; the 6 FX scenes of broadcast_scene have a `Sound` child.
## - fx_text_gone: nothing in scenes/ names FxSoundMap, fx_sounds.tres or SoundBus.fx_cue.
## - fx_parity: when tools/migrate/055o_fx_parity.json is there (the one-shot migration's snapshot of how every FX sounded
##   before), each consumer has the same streams and numbers as the cue it used to have. The file goes with the migration.
## Open gate only:
## - soul_mole_replicated: the Soul Mole's sound of taking the soul plays from the carrier's replicated phase (LEAVING), the
##   state a client of a dedicated server has, not from `reached`, which only the server emits.
## Prints `SOUND REFS typed=<n> text=<m> null=<k> parity=<p>/<q>`.

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
const EXPECTED_TYPED := 80
const EXPECTED_PARTICLES := 31
const EXPECTED_BEAMS := 6


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
	var played := SoundBus.sound_log.size() == 1 and last.get("emitter") == &"CaseMole" and last.get("event") == SoundEvent.CAST \
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
