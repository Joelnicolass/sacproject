extends Node

## Counts how many effects the server sends and how many a client draws (RFC-055 055x, criterion 5). Put one in the server process and one in each
## client of a networked match (the same scene or an AgentKit child); it only listens to FxBus.played and, on the server, broadcasts `count` bursts of
## `fx` at spread-out points, one per `every_frames` frames, after `start_delay_s`.
##   server: prints  FX_NET role=server sent=<n> labels=<hash>
##   client: prints  FX_NET role=client heard=<n> unresolved=<n> labels=<hash>   (after `settle_s` without a new one, and once more at the end)
## The runner compares them: heard >= 98 % of sent, unresolved = 0, and the same `labels` hash on both sides (the same effects in the same order).
## Plays nothing on its own on a client and changes no rule.

const FX := preload("res://data/fx/blood.tres")
const BEAM := preload("res://data/fx/beams/lightning.tres")

@export var count := 100
@export var every_frames := 2
@export var start_delay_s := 3.0
@export var settle_s := 4.0

var heard := 0
var sent := 0
var _labels := PackedStringArray()
var _idle_s := 0.0
var _printed := false


func _ready() -> void:
	FxBus.played.connect(_on_played)
	if MpKit.is_server():
		_send.call_deferred()


func _process(delta: float) -> void:
	if MpKit.is_server() or heard == 0 or _printed:
		return
	_idle_s += delta
	if _idle_s >= settle_s:
		_printed = true
		print("FX_NET role=client heard=%d unresolved=%d labels=%s" % [heard, FxWire.unresolved, _hash()])


func _on_played(kind: StringName, fx: Resource, _at: Vector3) -> void:
	if kind != FxBus.KIND_BURST and kind != FxBus.KIND_BEAM:
		return
	heard += 1
	_idle_s = 0.0
	_labels.append("%s:%s" % [kind, FxWire.label_of(fx)])


func _send() -> void:
	await get_tree().create_timer(start_delay_s).timeout
	for index in count:
		var at := Vector3(float(index % 10) * 2.0, 1.0, floorf(index / 10.0) * 2.0)
		if index % 5 == 4:
			FxBus.broadcast_beam(BEAM, at, at + Vector3(0.0, 4.0, 0.0))
		else:
			FxBus.broadcast(FX, at)
		sent += 1
		for _frame in every_frames:
			await get_tree().process_frame
	print("FX_NET role=server sent=%d labels=%s" % [sent, _hash()])


func _hash() -> String:
	return "\n".join(_labels).md5_text()
