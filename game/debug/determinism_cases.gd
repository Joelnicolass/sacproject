extends RefCounted

## RFC-032 cases of rules_suite: simulation time is MatchClock ticks, not the render clock (032b).
## - spellbook_cadence: a cooldown loses exactly 1/60 s per tick of the match; render frames without a tick do not
##   move it, and the Spellbook has no _process.
## - match_clock_pause: SceneTree.physics_frame keeps coming while the tree is paused, but now() stands still (and so
##   does a running cooldown); unpaused, it counts one per frame again.
## `run(host)` adds its own wizard under `host` and removes it at the end. rules_suite has no HighNoon: MatchClock hooks
## itself lazily on the first now().

const WIZARD_SCENE := preload("res://scenes/world/wizard/wizard_body.tscn")
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
