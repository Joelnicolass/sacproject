@tool
class_name HoldBody
extends Node

## While a SpellCarrier waits on its target (CarrierHold) this keeps the target stunned (every time
## its own stun cooldown allows it) and swells it a little more each tick, from 0 to 1 of
## `DevourGrowth.inflation`, so the body is at its biggest when the wait ends. Intestinal
## Vaporization: the carrier's TargetEffect gibs it then. If the wait ends in some other way the
## body goes back to its size. It does not wait (CarrierHold) and it does not burst the body
## (GibEffect). Server (or solo) only; every peer draws the swelling from the replicated
## `inflation`.

@export var carrier: SpellCarrier
## The stun's own cooldown for the body, in seconds.
@export_range(0.0, 20.0, 0.1, "suffix:s") var stun_cooldown_s := 3.0
@export var stunned_path := NodePath("Afflictions/Stunned")

var _target: Node3D
var _ticks := 0
var _total := 1


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if carrier != null
		else PackedStringArray(["The SpellCarrier is missing."])
	)


func _ready() -> void:
	set_physics_process(false)
	if Engine.is_editor_hint() or carrier == null or not multiplayer.is_server():
		return
	carrier.arrived.connect(_on_arrived)
	carrier.ended.connect(_on_ended)


func _on_arrived(target: Node3D) -> void:
	_target = target
	_ticks = 0
	_total = maxi(1, carrier.hold.wait_ticks() if carrier.hold != null else 1)
	set_physics_process(target != null)


func _physics_process(_delta: float) -> void:
	if not BodyEffect.is_live(_target):
		set_physics_process(false)
		return
	_ticks += 1
	var stunned := _target.get_node_or_null(stunned_path) as Stunned
	if stunned != null:
		stunned.stun_with_cooldown(MatchClock.ticks_for(stun_cooldown_s))
	_swell(minf(1.0, float(_ticks) / float(_total)))


func _on_ended() -> void:
	if BodyEffect.is_live(_target):
		_swell(0.0)


func _swell(amount: float) -> void:
	var growth := DevourGrowth.of(_target)
	if growth != null:
		growth.inflation = amount
