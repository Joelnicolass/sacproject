@tool
class_name FrogCling
extends Node

## What a frog does when it touches a creature: it sticks to it (the body's Clinging counts it and slows the body ×0.6 for each frog) and,
## after `fuse_s`, or as soon as the body can no longer be infected, it ends where it is (DropBlast bursts it). It asks its ZoneDrop to
## stick (attach) and to end (finish); it does not hop (FrogHop) nor hurt (DropBlast). Server (or solo) only.

@export var drop: ZoneDrop
## What each frog on a body multiplies its pace by.
@export_range(0.05, 1.0, 0.01) var factor := 0.6
@export_range(0.5, 30.0, 0.5, "suffix:s") var fuse_s := 5.0

var _body: Node3D
var _held := 0


func _ready() -> void:
	set_physics_process(false)
	if not Engine.is_editor_hint() and drop != null and multiplayer.is_server():
		drop.touched.connect(_on_touched)


func _on_touched(body: Node3D, _at: Vector3) -> void:
	var clinging := Clinging.of(body)
	if _body != null or clinging == null:
		return
	_body = body
	_held = 0
	clinging.stick(Clinging.FROGS, MatchClock.ticks_for(fuse_s) + 1, factor)
	drop.attach(body)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_held += 1
	var poisoning := Poisoning.of(_body)
	if _held > MatchClock.ticks_for(fuse_s) or poisoning == null or not poisoning.can_be_poisoned():
		set_physics_process(false)
		drop.finish(_body)


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if drop != null else PackedStringArray(["The frog (ZoneDrop) that clings is missing."])
