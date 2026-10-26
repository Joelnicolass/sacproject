extends Node3D

## RFC-029 029b bench (window only; FxBus is inert headless). Two parts:
## 1. Flight: the children of %Flyers circle for `flight_s`, each with its FxTrail (wrath, ekba and rock
##    trails at their game rates, 4 of each in flight). Every frame it reads the pool from FxBus's
##    children; a type whose playing count reached its cap may have restarted a live puff
##    (`fx_pool_pico <type> <peak>/<cap> ok|TOPE`).
## 2. CPU, with the pool idle: mean µs of FxBus.play for each trail type and ms per Wrath burst event
##    (its three bursts). Enmienda del criterio 3 (RFC-029 §13): trails ≤ 50 µs, the burst ≤ 0.5 ms.
## Pass `-- --quit` to quit at the end.

const _POOL := preload("res://debug/fx/fx_pool_count.gd")

@export var flight_s := 3.0
@export var radius_m := 6.0
@export var turns_per_s := 0.25
## Wait after the flight until every puff is idle again.
@export var settle_s := 4.0
@export var trail_types: Array[ParticleType] = [preload("res://data/fx/wrath_trail.tres"), preload("res://data/fx/spit_trail.tres"),
		preload("res://data/fx/rock_trail.tres")]
@export var trail_plays := 32
## Bursts of one Wrath explosion (wrath_strike.gd _explode).
@export var burst_types: Array[ParticleType] = [preload("res://data/fx/wrath_explosion1.tres"), preload("res://data/fx/wrath_explosion2.tres"),
		preload("res://data/fx/wrath_particle.tres")]
@export var burst_events := 6
@export var trail_budget_us := 50.0
@export var burst_budget_ms := 0.5

@onready var _flyers: Node3D = %Flyers

var _clock := 0.0
var _peaks: Dictionary = {}


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("fx_pool_bench: sin ventana, FxBus no reproduce")
		_finish()
		return
	_run.call_deferred()


func _process(delta: float) -> void:
	_clock += delta
	var count := _flyers.get_child_count()
	for i in count:
		var flyer := _flyers.get_child(i) as Node3D
		var angle := TAU * (turns_per_s * _clock + float(i) / float(count))
		flyer.position = Vector3(cos(angle) * radius_m, 1.5 + 0.25 * float(i % 3), sin(angle) * radius_m)


func _run() -> void:
	await get_tree().create_timer(flight_s).timeout
	_set_trails(false)
	for type: ParticleType in trail_types:
		var type_name := FxWire.label_of(type)
		var row: Vector3i = _POOL.by_type(FxBus).get(type_name, Vector3i.ZERO)
		var peak := int(_peaks.get(type_name, 0))
		print("fx_pool_pico %s %d/%d %s" % [type_name, peak, row.z, "ok" if peak < row.z else "TOPE"])
	await get_tree().create_timer(settle_s).timeout
	print("%.0f s despues: %s" % [settle_s, _POOL.line(FxBus)])
	_measure()
	_finish()


func _physics_process(_delta: float) -> void:
	var rows := _POOL.by_type(FxBus)
	for type: ParticleType in trail_types:
		var type_name := FxWire.label_of(type)
		var row: Vector3i = rows.get(type_name, Vector3i.ZERO)
		_peaks[type_name] = maxi(int(_peaks.get(type_name, 0)), row.x)


func _measure() -> void:
	var far := Vector3(0.0, -500.0, 0.0)
	for type: ParticleType in trail_types:
		var type_name := FxWire.label_of(type)
		var total := 0
		for i in trail_plays:
			var t0 := Time.get_ticks_usec()
			FxBus.play(type, far)
			total += Time.get_ticks_usec() - t0
		var mean := float(total) / float(trail_plays)
		print("fx_play %s media %.1f us (n %d) %s" % [type_name, mean, trail_plays, "ok" if mean <= trail_budget_us else "FALLA"])
	var worst := 0
	var sum := 0
	for i in burst_events:
		var t0 := Time.get_ticks_usec()
		for type: ParticleType in burst_types:
			FxBus.play(type, far)
		var spent := Time.get_ticks_usec() - t0
		sum += spent
		worst = maxi(worst, spent)
	print("fx_burst wrath media %.3f ms max %.3f ms (n %d) %s" % [float(sum) / 1000.0 / float(burst_events), float(worst) / 1000.0, burst_events, "ok" if float(worst) / 1000.0 <= burst_budget_ms else "FALLA"])
	print("fps %d" % Engine.get_frames_per_second())


func _set_trails(on: bool) -> void:
	for flyer in _flyers.get_children():
		for child in flyer.get_children():
			if child is FxTrail:
				(child as FxTrail).emitting = on


func _finish() -> void:
	if OS.get_cmdline_user_args().has("--quit"):
		get_tree().quit()
