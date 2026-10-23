extends RefCounted

## RFC-032 cases of rules_suite: simulation time is MatchClock ticks, not the render clock (032b).
## - spellbook_cadence: a cooldown loses exactly 1/60 s per tick of the match; render frames without a tick do not
##   move it, and the Spellbook has no _process.
## - match_clock_pause: SceneTree.physics_frame keeps coming while the tree is paused, but now() stands still (and so
##   does a running cooldown); unpaused, it counts one per frame again.
## - sim_rng_lint (032c): no script of the simulation (scenes/**, without the presentation and glue folders in LINT_SKIP_DIRS) draws from the global RNG
##   (rand*, randomize, seed, shuffle, pick_random), makes a RandomNumberGenerator that MatchSeed does not seed, or sorts
##   by instance_id. Presentation and seeded-by-hand exceptions are an explicit list (LINT_*). lint(root) takes any
##   folder, so a sabotaged copy outside the project can prove it fails.
## - avoidance_pause (032d, 036f): a body steered by BodyAvoidance gets its answer once; the 120 ticks of pause bring no
##   second answer (the server keeps stepping, the stale velocity is not applied) and the body does not move; in play
##   it is answered again each tick it steers.
## - vortex_life (032d): a RedVortex with max_life_s 1.0 is freed after 60 ticks (±1) of the match.
## `run(host)` adds its own wizard under `host` and removes it at the end. rules_suite has no HighNoon: MatchClock hooks
## itself lazily on the first now().

const WIZARD_SCENE := preload("res://scenes/wizards/wizard_body.tscn")
const AVOIDANCE_SCENE := preload("res://scenes/units/movement/body_avoidance.tscn")
const VORTEX_SCENE := preload("res://scenes/sacrifice/red_vortex.tscn")
const SIM_ROOT := "res://scenes"
## Paths (relative to the root) skipped by sim_rng_lint: presentation folders and files.
const LINT_SKIP_DIRS: Array[String] = ["look/", "ui/", "fx/", "net/", "core/", "gods/"]
## Whole files allowed: the owner of chance, and selection (human input, RFC-032 §8: its sort by instance_id stays).
const LINT_ALLOWED_FILES: Array[String] = ["match/match_seed.gd", "orders/selection.gd"]
## Single lines allowed (file -> stripped line): generators seeded by hand from a stable number, for presentation
## (spin of a shot) or from a seed that is already the match's (biome).
const LINT_ALLOWED_LINES := {
	"match/biome_rules.gd": "var rng := RandomNumberGenerator.new()",  # rng.seed = match_seed (the biome stream)
	"units/attacks/ranged_shot.gd": "var rng := RandomNumberGenerator.new()",  # spin of the shot, hash(name)
	"spells/rock_projectile.gd": "var rng := RandomNumberGenerator.new()",  # spin of the rock, hash(name)
	"audio/sound_bus.gd": "var _rng := RandomNumberGenerator.new()",  # RFC-052: own generator, seeded with rng_seed
	"audio/music_director.gd": "var _rng := RandomNumberGenerator.new()",  # RFC-052 052f: battle track, seeded with rng_seed
	"audio/ambience_director.gd": "var _rng := RandomNumberGenerator.new()",  # RFC-052 052g: one-shots, seeded with rng_seed
}
const VORTEX_LIFE_S := 1.0
const PAUSE_TICKS := 120
const GOD := "james"
const RENDER_FRAMES := 12
const SLOW_TICKS_PER_SECOND := 4

var _host: Node3D
var _root: Node3D


func run(host: Node3D) -> Dictionary:
	_host = host
	_root = Node3D.new()
	_root.name = "DeterminismCases"
	_host.add_child(_root)
	var wizard := WIZARD_SCENE.instantiate() as WizardBody
	wizard.owner_slot = 1
	wizard.god = GOD
	_root.add_child(wizard)
	await _ticks(2)
	var book: Node = wizard.get_node("Spellbook")
	var out := {}
	out["spellbook_cadence"] = await _cadence(book)
	out["match_clock_pause"] = await _pause(book)
	out["sim_rng_lint"] = _verdict("sim_rng_lint", lint(SIM_ROOT))
	out["avoidance_pause"] = await _avoidance_pause()
	out["vortex_life"] = await _vortex_life()
	_root.queue_free()
	return out


func _cadence(book: Node) -> Dictionary:
	var checks := {}
	var methods: Array[String] = []
	for method in book.get_script().get_script_method_list():
		methods.append(str(method.get("name")))
	checks["no_process"] = not methods.has("_process") and not book.is_processing()
	var spell: SpellType = book.call("spell_at", 0)
	checks["has_spell"] = spell != null
	if spell == null:
		return _verdict("spellbook_cadence", checks)
	book.call("apply_cooldown", spell.tag)
	var start := MatchClock.now()
	var c := float(book.call("cooldown", 0))
	checks["c"] = c
	checks["cooling"] = c > 1.0
	await _ticks(30)
	var after := float(book.call("cooldown", 0))
	checks["ticks_counted"] = MatchClock.now() - start
	checks["after_30"] = after
	checks["thirty_ticks_take_half_a_second"] = MatchClock.now() - start == 30 and absf(after - (c - 0.5)) <= 1e-6
	## Render frames with (almost) no physics step in between: the cooldown moves only with the ticks that did happen.
	var rate := Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = SLOW_TICKS_PER_SECOND
	var still_frames := 0
	var consistent := true
	var last_now := MatchClock.now()
	var last_left := float(book.call("cooldown", 0))
	for _i in RENDER_FRAMES:
		await _host.get_tree().process_frame
		var now := MatchClock.now()
		var left := float(book.call("cooldown", 0))
		if now == last_now:
			still_frames += 1
			consistent = consistent and left == last_left
		consistent = consistent and absf(left - (c - (now - start) / 60.0)) <= 1e-6
		last_now = now
		last_left = left
	Engine.physics_ticks_per_second = rate
	checks["render_frames_without_tick"] = still_frames
	checks["render_frames_do_not_move_it"] = still_frames > 0 and consistent
	return _verdict("spellbook_cadence", checks)


func _pause(book: Node) -> Dictionary:
	var checks := {}
	var tree := _host.get_tree()
	var spell: SpellType = book.call("spell_at", 0)
	if spell != null:
		book.call("apply_cooldown", spell.tag)
	var left := float(book.call("cooldown", 0))
	var before := MatchClock.now()
	tree.paused = true
	## Each await returns only if physics_frame is emitted while paused (RFC-032 §7).
	await _ticks(30)
	var paused_now := MatchClock.now()
	var paused_left := float(book.call("cooldown", 0))
	tree.paused = false
	checks["now_before"] = before
	checks["now_after_pause"] = paused_now
	checks["pause_freezes_now"] = paused_now == before
	checks["pause_freezes_cooldown"] = left > 0.0 and paused_left == left
	await _ticks(30)
	checks["unpaused_counts_again"] = MatchClock.now() - paused_now == 30
	return _verdict("match_clock_pause", checks)


## Every .gd under `root` (but LINT_SKIP_DIRS) against the rules of sim_rng_lint. {files, offenders, clean}.
static func lint(root: String) -> Dictionary:
	var global_rng := RegEx.create_from_string("(?<![\\w.])(randf|randi|randf_range|randi_range|randfn|randomize|seed|rand_from_seed)\\s*\\(")
	var array_rng := RegEx.create_from_string("\\.(shuffle|pick_random)\\s*\\(")
	var made := RegEx.create_from_string("var\\s+(\\w+)\\s*(:=|:\\s*RandomNumberGenerator\\s*=)\\s*RandomNumberGenerator\\.new\\(\\)")
	var offenders: Array[String] = []
	var files := _scripts(root.trim_suffix("/"), "")
	for rel in files:
		if LINT_ALLOWED_FILES.has(rel):
			continue
		var text := FileAccess.get_file_as_string(root.trim_suffix("/") + "/" + rel)
		var allowed: String = LINT_ALLOWED_LINES.get(rel, "")
		var lines := text.split("\n")
		for i in lines.size():
			var code := _code_of(lines[i]).strip_edges()
			if code.is_empty() or (allowed != "" and code == allowed):
				continue
			var why := ""
			if global_rng.search(code) or array_rng.search(code):
				why = "RNG global"
			elif code.contains("RandomNumberGenerator.new()"):
				var found := made.search(code)
				if found == null or not text.contains("MatchSeed.seed_rng(%s," % found.get_string(1)):
					why = "RandomNumberGenerator sin MatchSeed"
			elif code.contains("sort_custom") and code.contains("get_instance_id"):
				why = "orden por instance_id"
			if why != "":
				offenders.append("%s:%d %s «%s»" % [rel, i + 1, why, code.left(80)])
	return {"files": files.size(), "offenders": offenders, "clean": files.size() > 0 and offenders.is_empty()}


static func _scripts(root: String, rel: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root + ("/" + rel if rel != "" else ""))
	if dir == null:
		return out
	for sub in dir.get_directories():
		var child := rel + sub + "/"
		if not LINT_SKIP_DIRS.has(child):
			out.append_array(_scripts(root, child))
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(rel + file)
	return out


## The line without its comment (a # outside a string).
static func _code_of(line: String) -> String:
	var quote := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		i += 1
		if quote != "":
			if c == "\\":
				i += 1
			elif c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
		elif c == "#":
			return line.left(i - 1)
	return line


## A body steered once (BodyAvoidance.steer) is answered once, in the same physics step; during PAUSE_TICKS of pause
## (the tree stops, the navigation server does not) it gets no other answer and stands still; steering again in play
## is answered again.
func _avoidance_pause() -> Dictionary:
	var checks := {}
	var tree := _host.get_tree()
	var probe := CharacterBody3D.new()
	probe.name = "AvoidanceProbe"
	_root.add_child(probe)
	probe.global_position = Vector3(0.0, 40.0, 0.0)
	var agent := AVOIDANCE_SCENE.instantiate() as BodyAvoidance
	agent.body = probe
	probe.add_child(agent)
	var answers := [0]
	agent.solved.connect(func(flat: Vector3) -> void:
		answers[0] += 1
		probe.global_position += flat / 60.0)
	await _ticks(2)
	checks["steers"] = agent.steer(Vector3(2.0, 0.0, 0.0))
	await _ticks(1)
	checks["answered_once"] = answers[0] == 1
	var after_answer := probe.global_position
	tree.paused = true
	await _ticks(PAUSE_TICKS)
	tree.paused = false
	checks["no_answer_in_pause"] = answers[0] == 1
	checks["stands_still_in_pause"] = probe.global_position == after_answer
	checks["steers_again_in_play"] = agent.steer(Vector3(2.0, 0.0, 0.0))
	await _ticks(1)
	checks["answered_in_play"] = answers[0] == 2
	probe.queue_free()
	return _verdict("avoidance_pause", checks)


## A RedVortex with max_life_s VORTEX_LIFE_S: the tick it asks to be freed, counted from the tick it entered.
func _vortex_life() -> Dictionary:
	var checks := {}
	var vortex := VORTEX_SCENE.instantiate() as RedVortex
	vortex.name = "VortexLifeProbe"
	vortex.max_life_s = VORTEX_LIFE_S
	var start := MatchClock.now()
	_root.add_child(vortex)
	var want := MatchClock.ticks_for(VORTEX_LIFE_S)
	var queued_at := -1
	for _i in want + 30:
		await _ticks(1)
		if not is_instance_valid(vortex) or vortex.is_queued_for_deletion():
			## Asked in the _physics_process of the tick before this physics_frame.
			queued_at = MatchClock.now() - 1
			break
	var lived := queued_at - start + 1 if queued_at >= 0 else -1
	checks["want_ticks"] = want
	checks["lived_ticks"] = lived
	checks["freed_at_60_pm_1"] = lived >= 0 and absi(lived - want) <= 1
	if is_instance_valid(vortex) and not vortex.is_queued_for_deletion():
		vortex.queue_free()
	return _verdict("vortex_life", checks)


func _ticks(count: int) -> void:
	for _i in count:
		await _host.get_tree().physics_frame


func _verdict(name: String, checks: Dictionary) -> Dictionary:
	var ok := true
	for key in checks:
		if checks[key] is bool and not checks[key]:
			ok = false
			print("determinism_cases: falla %s.%s" % [name, key])
	checks["ok"] = ok
	print("determinism_cases: %s %s" % [name, checks])
	return checks
