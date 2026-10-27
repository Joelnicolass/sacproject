extends Node3D

## RFC-053 053f (F375): the combat feel. With a window: `debug_hit` (K) takes 20 % of the next body (the local wizard, then each
## Trogg): the camera shakes only on the wizard's hits, a number rises over each. Options → Jugabilidad changes both.
## Headless, `-- --feel-script` checks (FeelPrefs changed for this run only, never saved):
## - shake at 100 %: a 20 % hit on the wizard moves the camera (offset > 0, at most 0,35 m) and under 0,01 m at 0,5 s;
## - shake at 0 %: offset and roll exactly 0 and the camera where it was;
## - an explosion of the ShakeMap beyond `max_distance_m` adds nothing; one close by does;
## - damage numbers: a hit shows one, a second hit within merge_s adds to it, it is gone after its life; off in FeelPrefs: none.
## `-- --feel-match` puts a real match (high_noon.tscn) in this headless process: its CameraShake and DamageNumbers exist and
## none is active. Prints `FEEL <check>: PASS|FAIL` and `FEEL PASS|FAIL`; quits 0 / 1. Watchdog: `timeout_s` real seconds.

const MATCH_SCENE := "res://debug/match/high_noon.tscn"
const EXPLOSION: ParticleType = preload("res://data/fx/wrath_explosion1.tres")

## Real seconds (not game time: --fixed-fps would stretch a game-time timer).
@export var timeout_s := 20.0
@export var camera: Camera3D
@export var shake: CameraShake
@export var numbers: DamageNumbers
@export var wizard: Node3D
## Bodies `debug_hit` takes 20 % of, in turn.
@export var targets: Array[Node3D] = []
@export var status: Label
## Share of the maximum one hit takes.
@export_range(0.0, 1.0) var hit_fraction := 0.2

var _next := 0
var _done := false
var _failed := false
var _deadline := 0
var _checking := false


func _ready() -> void:
	_deadline = Time.get_ticks_msec() + int(timeout_s * 1000.0)
	var args := OS.get_cmdline_user_args()
	if args.has("--feel-script"):
		_checking = true
		_feel_script.call_deferred()
	elif args.has("--feel-match"):
		_checking = true
		_feel_match.call_deferred()


func _process(_delta: float) -> void:
	if _checking and not _done and Time.get_ticks_msec() > _deadline:
		_done = true
		print("FEEL FAIL timeout")
		get_tree().quit(1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_hit") and not targets.is_empty():
		var body := targets[_next % targets.size()]
		_next += 1
		hit(body)
		if status:
			status.text = "K: golpe del 20 %% al siguiente cuerpo · último: %s" % body.name


## Takes `hit_fraction` of the body's maximum off its health, as a hit would show on any peer (Health.changed).
func hit(body: Node3D) -> void:
	var health := body.get_node_or_null("Health") as Health
	if health and health.maximum > 0.0:
		health.current = maxf(health.current - health.maximum * hit_fraction, 1.0)


func _feel_script() -> void:
	var prefs := shake.prefs
	await _wait(0.3)
	var rest := camera.global_position
	_check("shake active under the check", shake.is_active() and numbers.is_active())
	# 100 %: a 20 % hit on the wizard.
	prefs.set_shake_scale(1.0, false)
	shake.trauma = 0.0
	hit(wizard)
	var peak := 0.0
	var moved := 0.0
	var left := 0.5
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
		peak = maxf(peak, shake.offset().length())
		moved = maxf(moved, camera.global_position.distance_to(rest))
	var settled := shake.offset().length()
	print("FEEL_NOTE 100%%: peak %.4f m, camera moved %.4f m, at 0.5 s %.5f m" % [peak, moved, settled])
	_check("100 %: a 20 % wizard hit shakes (peak > 0)", peak > 0.0005 and moved > 0.0005)
	_check("100 %: peak <= 0.35 m", peak <= 0.35 and moved <= 0.35 + 0.001)
	_check("100 %: under 0.01 m at 0.5 s", settled < 0.01)
	# 0 %: nothing at all.
	prefs.set_shake_scale(0.0, false)
	await _wait(0.1)
	rest = camera.global_position
	hit(wizard)
	var any := false
	left = 0.3
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()
		if shake.offset() != Vector3.ZERO or shake.roll() != 0.0 or camera.global_position != rest:
			any = true
	_check("0 %: offset and roll exactly 0", not any)
	# Explosions: beyond max_distance_m nothing; close by, some.
	prefs.set_shake_scale(1.0, false)
	shake.trauma = 0.0
	var far := camera.global_position + Vector3(shake.shake_map.max_distance_m + 5.0, 0.0, 0.0)
	FxBus.play(EXPLOSION, far)
	await get_tree().process_frame
	_check("explosion beyond max distance adds nothing", shake.trauma == 0.0 and shake.offset() == Vector3.ZERO)
	FxBus.play(EXPLOSION, camera.global_position + Vector3(4.0, 0.0, 0.0))
	_check("explosion close by shakes", shake.trauma > 0.0)
	# Damage numbers (once the wizard's numbers of the shake checks are gone).
	await _wait(numbers.life_s + 0.1)
	prefs.set_damage_numbers(true, false)
	var trogg := targets[1]
	hit(trogg)
	await get_tree().process_frame
	_check("a hit shows one number (%d)" % numbers.live_count(), numbers.live_count() == 1)
	var first := numbers.live_texts()
	await _wait(0.05)
	hit(trogg)
	await get_tree().process_frame
	var merged := numbers.live_texts()
	print("FEEL_NOTE numbers %s then %s" % [first, merged])
	_check("a second hit within merge_s adds to it", numbers.live_count() == 1 and merged.size() == 1 and first.size() == 1 \
		and int(merged[0]) > int(first[0]))
	await _wait(numbers.life_s + 0.1)
	_check("the number is gone after its life", numbers.live_count() == 0)
	prefs.set_damage_numbers(false, false)
	hit(targets[2])
	await get_tree().process_frame
	_check("off in FeelPrefs: no number", numbers.live_count() == 0)
	prefs.set_damage_numbers(true, false)
	_finish()


func _feel_match() -> void:
	var world := (load(MATCH_SCENE) as PackedScene).instantiate()
	add_child(world)
	await _wait(0.2)
	var found := 0
	var active := 0
	for node in get_tree().get_nodes_in_group(CameraShake.GROUP):
		if not world.is_ancestor_of(node):
			continue
		found += 1
		if bool(node.call("is_active")):  # dynamic: CameraShake and DamageNumbers both answer it
			active += 1
			print("FEEL_NOTE active in the match: %s" % world.get_path_to(node))
	print("FEEL_NOTE headless match: %d presentation nodes, %d active" % [found, active])
	_check("headless match has CameraShake and DamageNumbers", found >= 2)
	_check("none of them is active", active == 0)
	world.queue_free()
	await get_tree().process_frame
	_finish()


func _finish() -> void:
	_done = true
	print("FEEL ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _check(label: String, ok: bool) -> void:
	print("FEEL %s: %s" % [label, "PASS" if ok else "FAIL"])
	if not ok:
		_failed = true
