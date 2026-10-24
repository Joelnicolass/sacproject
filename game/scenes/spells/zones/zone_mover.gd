@tool
class_name ZoneMover
extends Node

## A zone that chases its target: once it acts, every tick it moves toward the middle of the body the wizard clicked, at the spell's speed
## (it speeds up by the spell's acceleration each tick), and stays still when it arrives, when the body is gone, or when the click was the
## ground. Cloudkill's cloud hangs over it at a fixed height (a child marker of the zone). The only writer of the zone's position; the zone
## replicates it (`replicates_position`). Server (or solo) only.
## Ref: sacengine updateCloudkill (state.d:22079-22084); REA CloudKillRun 0x420a30 (speed 3, acceleration 0.3; how the acceleration enters is NOT VERIFIED).

@export var zone: GroundZone

var _speed := 0.0


func _ready() -> void:
	set_physics_process(not Engine.is_editor_hint() and zone != null and zone.is_authority())


func _physics_process(_delta: float) -> void:
	var target := zone.followed()
	if zone.phase != GroundZone.Phase.ACTIVE or target == null or not is_instance_valid(target):
		return
	var to := BodyNudge.center(target) - zone.global_position
	_speed = minf(zone.spell.speed_m_s, _speed + zone.spell.acceleration_m_s2)
	var step := minf(to.length(), _speed / MatchClock.TICKS_PER_SECOND_F)
	zone.global_position += to.normalized() * step


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if zone != null else PackedStringArray(["Falta la zona (GroundZone) que persigue."])
