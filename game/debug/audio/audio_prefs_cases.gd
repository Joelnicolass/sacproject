extends RefCounted

## RFC-052 052a (F360): AudioPrefs and its section [audio] of the settings file. Runs only on an isolated file
## (`--user-settings=user://t_audio….cfg`), never the player's; the runner refuses otherwise.
## - Defaults, a value written and read back by a fresh instance, the clamp, «Silenciar», a bad value, the other sections kept.
## - The dB rule (0 = silent and muted; linear_to_db otherwise) and SoundBus applying the shared instance to the buses.
## - default_bus_layout.tres: the five buses, each sending to Master.
## - The AgentKit rule (Master at 0 unless --audio-on), pure.


func run(_host: Node) -> Dictionary:
	var results := {}
	var file := UserSettings.path()
	if file == UserSettings.PATH or not file.get_file().begins_with("t_audio"):
		results["audio_prefs_isolated"] = {"ok": false, "reason": "falta --user-settings=user://t_audio….cfg", "path": file}
		return results
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	results["audio_bus_layout"] = _layout()
	results["audio_prefs_persist"] = _persist()
	results["audio_prefs_db"] = _db()
	results["audio_prefs_apply"] = _apply()
	results["audio_prefs_agent"] = _agent()
	return results


func _layout() -> Dictionary:
	var missing := []
	for bus in AudioPrefs.BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			missing.append(bus)
		elif bus != &"Master" and AudioServer.get_bus_send(index) != &"Master":
			missing.append("%s no manda a Master" % bus)
	return {"ok": missing.is_empty() and AudioServer.bus_count == 5, "count": AudioServer.bus_count, "missing": missing}


func _persist() -> Dictionary:
	UserSettings.write_values("graphics", {"vsync": false})
	var first := AudioPrefs.new()
	var defaults_ok := is_equal_approx(first.volume(&"Master"), 1.0) and is_equal_approx(first.volume(&"Music"), 0.7) \
		and not first.muted()
	first.set_volume(&"Music", 0.25)
	first.set_volume(&"Voice", 3.0)
	first.set_volume(&"Nope", 0.5)
	first.set_muted(true)
	var second := AudioPrefs.new()
	var read_ok := is_equal_approx(second.volume(&"Music"), 0.25) and is_equal_approx(second.volume(&"Voice"), 1.0) \
		and second.muted() and is_equal_approx(second.volume(&"Nope"), 0.0)
	var stored: Variant = UserSettings.read_value("audio", "music", null)
	var section_ok: bool = typeof(stored) == TYPE_FLOAT and is_equal_approx(float(stored), 0.25) \
		and UserSettings.read_value("graphics", "vsync", true) == false
	UserSettings.write_values("audio", {"sfx": "fuerte"})
	var third := AudioPrefs.new()
	var bad_ok := is_equal_approx(third.volume(&"SFX"), 1.0) and is_equal_approx(third.volume(&"Music"), 0.25)
	return {
		"ok": defaults_ok and read_ok and section_ok and bad_ok,
		"defaults": defaults_ok, "read_back": read_ok, "section": section_ok, "bad_value": bad_ok,
	}


func _db() -> Dictionary:
	var prefs := AudioPrefs.new()
	var zero := prefs.db_for(0.0)
	var half := prefs.db_for(0.5)
	var full := prefs.db_for(1.0)
	var ok := is_equal_approx(zero, prefs.silent_db) and absf(half - linear_to_db(0.5)) < 0.001 and is_equal_approx(full, 0.0)
	return {"ok": ok, "zero": zero, "half": half, "full": full}


func _apply() -> Dictionary:
	var shared := load(AudioPrefs.SHARED_PATH) as AudioPrefs
	if shared == null or SoundBus.prefs != shared:
		return {"ok": false, "reason": "SoundBus no usa la instancia compartida"}
	var music := AudioServer.get_bus_index(&"Music")
	var master := AudioServer.get_bus_index(&"Master")
	var before_music := shared.volume(&"Music")
	var before_muted := shared.muted()
	shared.set_muted(false)
	shared.set_volume(&"Music", 0.5)
	var half_db := AudioServer.get_bus_volume_db(music)
	var half_ok := absf(half_db - linear_to_db(0.5)) < 0.01 and not AudioServer.is_bus_mute(music)
	shared.set_volume(&"Music", 0.0)
	var zero_ok := AudioServer.is_bus_mute(music)
	shared.set_muted(true)
	var mute_ok := AudioServer.is_bus_mute(master)
	shared.set_muted(false)
	var unmute_ok := not AudioServer.is_bus_mute(master) or shared.volume(&"Master") <= 0.0
	shared.set_volume(&"Music", before_music)
	shared.set_muted(before_muted)
	return {
		"ok": half_ok and zero_ok and mute_ok and unmute_ok,
		"music_db_at_half": half_db, "zero_mutes": zero_ok, "mute_master": mute_ok, "unmute": unmute_ok,
	}


func _agent() -> Dictionary:
	var ok := AudioPrefs.agent_starts_silent(PackedStringArray(["--agent=flow"])) \
		and not AudioPrefs.agent_starts_silent(PackedStringArray(["--agent=flow", "--audio-on"])) \
		and not AudioPrefs.agent_starts_silent(PackedStringArray([])) \
		and not AudioPrefs.agent_starts_silent(PackedStringArray(["--user-settings=user://x.cfg"]))
	return {"ok": ok}
