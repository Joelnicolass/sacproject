extends RefCounted

## RFC-052 052f (F365) and 052g (F366): the music and the ambience.
## Open gate (--audio-probe):
## - mood_table (MusicMood, pure): every row of the original's rules, highest first (result > desecration > ritual near >
##   battle > calm), result_of and desecration_of from the local side's view.
## - music_set_fallback: a god's set answers calm itself and battle from its fallback (common); a mood nobody has is empty.
## - gauge_hysteresis (CombatGauge): enter at `enter`, stays under `exit` until `hold_s`, then off; a hit on the bound wizard
##   keeps the battle on for `wizard_damage_s`.
## - music_director (fixture sets): calm, then battle when the gauge flips (a track of the set), the old player stops
##   after the crossfade; victory is not restarted.
## - ambience_director (fixture set): the bed plays on its own player, one-shots come on the set's interval, around the
##   listener, emitter `ambience`.
## - global_rng: the directors and the gauge draw nothing from the global generator.
## - original_loops (only when data/audio/ has the original's sets): every ambience bed is a WAV that loops by itself
##   (`edit/loop_mode=2`), the looping moods' MP3s loop (`loop=true`) and victory/defeat do not.
## Closed gate (plain headless, --dedicated, --room-server):
## - music_closed: MusicDirector, AmbienceDirector and CombatGauge enter the tree, create no player and load no set.

const MUSIC_ROOT := "res://debug/audio/fixtures/music/"
const AMBIENCE_ROOT := "res://debug/audio/fixtures/ambience/"
const ORIGINAL_SETS: PackedStringArray = [
	"res://data/audio/music/james.tres",
	"res://data/audio/music/common.tres",
	"res://data/audio/music/menu.tres",
	"res://data/audio/ambience/james.tres",
	"res://debug/audio/fixtures/music/music/common.tres",
	"res://debug/audio/fixtures/ambience/ambience/james.tres",
]
const MUSIC_DIRECTOR := "res://scenes/audio/music_director.tscn"
const AMBIENCE_DIRECTOR := "res://scenes/audio/ambience_director.tscn"


func run(host: Node, open: bool) -> Dictionary:
	var results := {}
	if not open:
		results["music_closed"] = await _closed(host)
		return results
	results["mood_table"] = _mood_table()
	if not SoundBus.is_active():
		results["music_cases_active"] = {"ok": false, "reason": "SoundBus inactivo: falta --audio-probe"}
		return results
	results["music_set_fallback"] = _set_fallback()
	results["gauge_hysteresis"] = await _gauge(host)
	results["music_director"] = await _director(host)
	results["ambience_director"] = await _ambience(host)
	results["global_rng"] = await _global_rng(host)
	results["original_loops"] = _original_loops()
	SoundBus.stop_all()
	SoundLibrary.reset_roots()
	## Real time, not frames (--fixed-fps): the audio server lets go of the stopped playbacks a moment later.
	OS.delay_msec(200)
	for _i in 3:
		await host.get_tree().process_frame
	return results


func _mood_table() -> Dictionary:
	var R := MusicMood.Result
	var D := MusicMood.Desecration
	## [result, desecration, ritual_near, battle, expected]
	var rows := [
		[R.NONE, D.NONE, false, false, MusicMood.CALM],
		[R.NONE, D.NONE, false, true, MusicMood.BATTLE],
		[R.NONE, D.NONE, true, false, MusicMood.SACRIFICE],
		[R.NONE, D.NONE, true, true, MusicMood.SACRIFICE],
		[R.NONE, D.WINNING, false, false, MusicMood.WINNING],
		[R.NONE, D.WINNING, true, true, MusicMood.WINNING],
		[R.NONE, D.LOSING, false, true, MusicMood.LOSING],
		[R.NONE, D.LOSING, true, false, MusicMood.LOSING],
		[R.WON, D.LOSING, true, true, MusicMood.VICTORY],
		[R.WON, D.NONE, false, false, MusicMood.VICTORY],
		[R.LOST, D.WINNING, true, true, MusicMood.DEFEAT],
		[R.LOST, D.NONE, false, false, MusicMood.DEFEAT],
	]
	var checks := {}
	for i in rows.size():
		var row: Array = rows[i]
		var got := MusicMood.decide(row[0], row[1], row[2], row[3])
		checks["row_%d_%s" % [i, row[4]]] = got == row[4]
	checks["result_running"] = MusicMood.result_of(false, false, 1) == R.NONE
	checks["result_won"] = MusicMood.result_of(true, true, 1) == R.WON
	checks["result_lost"] = MusicMood.result_of(true, false, 2) == R.LOST
	checks["result_no_side"] = MusicMood.result_of(true, false, 0) == R.NONE
	checks["desecrate_ours"] = MusicMood.desecration_of(2, 1, 1) == D.LOSING
	checks["desecrate_theirs"] = MusicMood.desecration_of(1, 2, 1) == D.WINNING
	checks["desecrate_others"] = MusicMood.desecration_of(2, 3, 1) == D.NONE
	checks["desecrate_no_side"] = MusicMood.desecration_of(1, 2, 0) == D.NONE
	checks["worst_losing"] = MusicMood.worst(D.WINNING, D.LOSING) == D.LOSING
	checks["worst_winning"] = MusicMood.worst(D.NONE, D.WINNING) == D.WINNING
	checks["once"] = MusicMood.is_once(MusicMood.VICTORY) and MusicMood.is_once(MusicMood.DEFEAT) \
			and not MusicMood.is_once(MusicMood.BATTLE)
	return _verdict(checks)


func _set_fallback() -> Dictionary:
	var a := load("res://debug/audio/fixtures/beep_a.tres") as AudioStream
	var common := MusicSet.new()
	common.battle = [a, a]
	var god := MusicSet.new()
	god.calm = [a]
	god.fallback = common
	var checks := {}
	checks["own_calm"] = god.tracks(MusicMood.CALM).size() == 1
	checks["fallback_battle"] = god.tracks(MusicMood.BATTLE).size() == 2
	checks["nobody_victory"] = god.tracks(MusicMood.VICTORY).is_empty()
	checks["unknown_mood"] = god.tracks(&"nope").is_empty()
	return _verdict(checks)


func _gauge(host: Node) -> Dictionary:
	var wizard := Node3D.new()
	var health := Health.new()
	health.name = "Health"
	wizard.add_child(health)
	host.add_child(wizard)
	health.maximum = 100.0
	health.current = 100.0
	var gauge := CombatGauge.new()
	gauge.hold_s = 0.5
	gauge.wizard_damage_s = 1.0
	gauge.wizard = wizard
	host.add_child(gauge)
	var flips: Array[bool] = []
	gauge.battle_changed.connect(func(on: bool) -> void: flips.append(on))
	var checks := {}
	gauge.force(0.3)
	checks["below_enter"] = not gauge.is_battle()
	gauge.force(0.5)
	checks["enter"] = gauge.is_battle() and flips == [true]
	gauge.force(0.0)
	checks["held"] = gauge.is_battle()
	await _game_seconds(host, 0.8)
	gauge.sample()
	checks["released"] = not gauge.is_battle() and flips == [true, false]
	gauge.force(0.3)
	checks["between_stays_off"] = not gauge.is_battle()
	health.current = 80.0
	gauge.sample()
	checks["wizard_hit"] = gauge.is_battle() and not gauge.is_combat()
	await _game_seconds(host, 1.2)
	gauge.sample()
	checks["wizard_hit_expires"] = not gauge.is_battle()
	gauge.force(-1.0)
	checks["measured_without_units"] = gauge.intensity == 0.0
	gauge.queue_free()
	wizard.queue_free()
	return _verdict(checks)


func _director(host: Node) -> Dictionary:
	SoundLibrary.roots = PackedStringArray([MUSIC_ROOT])
	SoundLibrary.clear_cache()
	SoundBus.sound_log.clear()
	var gauge := CombatGauge.new()
	host.add_child(gauge)
	var director := (load(MUSIC_DIRECTOR) as PackedScene).instantiate() as MusicDirector
	director.gauge = gauge
	director.set_path = "music/james"
	host.add_child(director)
	var checks := {}
	checks["fallback_set"] = director.music_set != null and director.music_set.resource_path.ends_with("music/common.tres")
	checks["calm"] = director.mood == MusicMood.CALM and _logged(MusicMood.CALM)
	checks["two_players"] = director.get_child_count() == 2
	gauge.force(1.0)
	var battle_tracks := director.music_set.tracks(MusicMood.BATTLE)
	checks["battle"] = director.mood == MusicMood.BATTLE and _logged(MusicMood.BATTLE) \
			and battle_tracks.has(director.playing_stream())
	var playing_now := 0
	for child in director.get_children():
		if (child as AudioStreamPlayer).playing:
			playing_now += 1
	checks["crossfading"] = playing_now == 2
	await _game_seconds(host, director.music_set.crossfade_s + 0.2)
	playing_now = 0
	for child in director.get_children():
		if (child as AudioStreamPlayer).playing:
			playing_now += 1
	checks["old_stopped"] = playing_now == 1
	gauge.force(0.0)
	director.menu = true
	director.look()
	checks["menu_calm"] = director.mood == MusicMood.CALM
	director.queue_free()
	gauge.queue_free()
	return _verdict(checks)


func _ambience(host: Node) -> Dictionary:
	SoundLibrary.roots = PackedStringArray([AMBIENCE_ROOT])
	SoundLibrary.clear_cache()
	SoundBus.sound_log.clear()
	var listener := Node3D.new()
	host.add_child(listener)
	var before_listener: Node3D = SoundBus.listener
	SoundBus.listener = listener
	var director := (load(AMBIENCE_DIRECTOR) as PackedScene).instantiate() as AmbienceDirector
	director.set_path = "ambience/james"
	host.add_child(director)
	var checks := {}
	checks["bed"] = _logged(SoundEvent.BED, AmbienceDirector.EMITTER) and (director.get_child(0) as AudioStreamPlayer).playing
	checks["one_shots"] = director.has_one_shots()
	await _game_seconds(host, 2.0)
	var count := 0
	for entry: Dictionary in SoundBus.sound_log.entries():
		if entry.emitter == AmbienceDirector.EMITTER and entry.event == SoundEvent.AMBIENT and bool(entry.played):
			count += 1
	## The fixture's interval is 0.2-0.4 s: 2 s hold between 5 and 10.
	checks["interval"] = count >= 4 and count <= 11
	director.use_set("ambience/none")
	checks["no_set_silent"] = not (director.get_child(0) as AudioStreamPlayer).playing and not director.has_one_shots()
	director.queue_free()
	SoundBus.listener = before_listener
	listener.queue_free()
	return _verdict(checks)


func _global_rng(host: Node) -> Dictionary:
	SoundLibrary.roots = PackedStringArray([MUSIC_ROOT, AMBIENCE_ROOT])
	SoundLibrary.clear_cache()
	seed(4242)
	var expected := randi()
	seed(4242)
	var gauge := CombatGauge.new()
	host.add_child(gauge)
	var music := (load(MUSIC_DIRECTOR) as PackedScene).instantiate() as MusicDirector
	music.gauge = gauge
	music.set_path = "music/james"
	host.add_child(music)
	var ambience := (load(AMBIENCE_DIRECTOR) as PackedScene).instantiate() as AmbienceDirector
	ambience.set_path = "ambience/james"
	host.add_child(ambience)
	for i in 6:
		gauge.force(float(i % 2))
		ambience.play_one_shot()
	await _game_seconds(host, 0.6)
	var got := randi()
	music.queue_free()
	ambience.queue_free()
	gauge.queue_free()
	return _verdict({"same_next_randi": got == expected})


func _original_loops() -> Dictionary:
	SoundLibrary.roots = PackedStringArray(["res://data/audio/"])
	SoundLibrary.clear_cache()
	var checks := {}
	for god in ["james", "persephone", "pyro", "stratos", "charnel"]:
		var ambience := SoundLibrary.find("ambience/%s" % god) as AmbienceSet
		if ambience != null and ambience.bed != null:
			var loops := not ambience.bed.streams.is_empty()
			for stream in ambience.bed.streams:
				loops = loops and stream is AudioStreamWAV and (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
			checks["bed_loops_%s" % god] = loops
		var music := SoundLibrary.find("music/%s" % god) as MusicSet
		if music == null:
			continue
		for mood in MusicMood.ALL:
			for stream in music.tracks(mood):
				var mp3 := stream as AudioStreamMP3
				if mp3 != null:
					checks["%s_%s_%s" % [god, mood, stream.resource_path.get_file().get_basename()]] = mp3.loop != MusicMood.is_once(mood)
	var menu := SoundLibrary.find("music/menu") as MusicSet
	if menu != null:
		for stream in menu.tracks(MusicMood.CALM):
			checks["menu_loops"] = stream is AudioStreamMP3 and (stream as AudioStreamMP3).loop
	SoundLibrary.reset_roots()
	## The sets are there (and their files): something must have been checked.
	if SoundLibrary.has_dependencies("res://data/audio/music/common.tres") and ResourceLoader.exists("res://data/audio/music/common.tres"):
		checks["original_checked"] = checks.size() >= 10
	var verdict := _verdict(checks)
	verdict["checked"] = checks.size()
	return verdict


func _closed(host: Node) -> Dictionary:
	var gauge := CombatGauge.new()
	host.add_child(gauge)
	var music := (load(MUSIC_DIRECTOR) as PackedScene).instantiate() as MusicDirector
	music.gauge = gauge
	music.set_path = "music/james"
	host.add_child(music)
	var ambience := (load(AMBIENCE_DIRECTOR) as PackedScene).instantiate() as AmbienceDirector
	ambience.set_path = "ambience/james"
	host.add_child(ambience)
	for _i in 3:
		await host.get_tree().process_frame
	music.use_god(&"pyro")
	ambience.use_god(&"stratos")
	gauge.force(1.0)
	music.look()
	var checks := {}
	checks["no_players"] = music.get_child_count() == 0 and ambience.get_child_count() == 0
	checks["no_set"] = music.music_set == null and ambience.ambience_set == null
	checks["no_battle"] = not gauge.is_battle()
	var cached := PackedStringArray()
	for path in ORIGINAL_SETS:
		if ResourceLoader.has_cached(path):
			cached.append(path)
	for path in ["res://data/audio/music/pyro.tres", "res://data/audio/ambience/stratos.tres"]:
		if ResourceLoader.has_cached(path):
			cached.append(path)
	checks["nothing_loaded"] = cached.is_empty()
	music.queue_free()
	ambience.queue_free()
	gauge.queue_free()
	var verdict := _verdict(checks)
	if not cached.is_empty():
		verdict["cached"] = cached
	return verdict


func _logged(event: StringName, emitter: StringName = MusicDirector.EMITTER) -> bool:
	for entry: Dictionary in SoundBus.sound_log.entries():
		if entry.emitter == emitter and entry.event == event and bool(entry.played):
			return true
	return false


## Waits `seconds` of game time (the clocks of the gauge and the directors run on _process deltas).
func _game_seconds(host: Node, seconds: float) -> void:
	var tree := host.get_tree()
	var left := seconds
	while left > 0.0:
		await tree.process_frame
		left -= host.get_process_delta_time()


func _verdict(checks: Dictionary) -> Dictionary:
	var failed := []
	for key in checks:
		if not checks[key]:
			failed.append(key)
	return {"ok": failed.is_empty(), "failed": failed}
