class_name DetRecorder
extends Node

## The record of a deterministic run: every line is "<tick> <kind> <text>", hashed in order into a sha256.
## Two runs with the same inputs must give the same digest, whatever the render clock (fixed, stress, window).
## It only watches: it never decides or changes the game. Wall-clock times must never enter a line.

signal finished(digest: String)

## Also keep every line (needed to write the `.events` file and to find where two runs part ways).
@export var keep_lines := false
## With true (default) the recorder counts physics ticks itself. With false the owner calls advance() at the
## point of its own physics step where the clock must move (the order of _physics_process then does not change).
@export var self_tick := true
## Decimals of the positions written by sample().
@export var position_decimals := 1

## Ticks since start(): the clock of every line.
var tick := 0
var running := false
var lines := PackedStringArray()
var line_count := 0

var _ctx := HashingContext.new()
var _digest := ""


func start() -> void:
	tick = 0
	line_count = 0
	lines = PackedStringArray()
	_digest = ""
	_ctx.start(HashingContext.HASH_SHA256)
	running = true


func stop() -> void:
	running = false


func _physics_process(_delta: float) -> void:
	if self_tick:
		advance()


## One tick of the clock.
func advance() -> void:
	if running:
		tick += 1


## One line of the record: the tick, a kind and the text.
func record(kind: String, text: String) -> void:
	if not running:
		return
	var line := "%d %s %s" % [tick, kind, text]
	_ctx.update(line.to_utf8_buffer())
	_ctx.update(PackedByteArray([10]))
	line_count += 1
	if keep_lines:
		lines.append(line)


## Positions of the bodies, rounded to `position_decimals`, sorted by name.
func sample(bodies: Array) -> void:
	var sorted: Array = bodies.filter(func(body: Variant) -> bool: return is_instance_valid(body))
	sorted.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name) < String(b.name))
	for body: Node3D in sorted:
		record("pos", "%s %s" % [body.name, fmt(body.global_position)])


## Sha256 of the lines so far. It finishes the hashing context, so the first call fixes the value (later calls repeat it).
func digest() -> String:
	if _digest.is_empty():
		_digest = _ctx.finish().hex_encode()
	return _digest


## Adds `digest`, `events` (line count) and `end_tick` to the report and writes what the runner asked for:
## the JSON to `--out=` and the lines to `--events=` (the latter needs keep_lines = true).
func write_outputs(report: Dictionary) -> void:
	report["digest"] = digest()
	report["events"] = line_count
	report["end_tick"] = tick
	var out_path := DetCli.out_path()
	if not out_path.is_empty():
		_write(out_path, JSON.stringify(report, "\t"))
	var events_path := DetCli.events_path()
	if not events_path.is_empty():
		if not keep_lines:
			push_warning("DetRecorder: --events given but keep_lines is false; the file will be empty")
		_write(events_path, "\n".join(lines) + "\n")
	finished.emit(report["digest"])


func fmt(at: Vector3) -> String:
	var f := "%%.%df" % position_decimals
	return ",".join([f % at.x, f % at.y, f % at.z])


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("DetRecorder: cannot write %s" % path)
		return
	file.store_string(text)
