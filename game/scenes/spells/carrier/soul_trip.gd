class_name SoulTrip
extends RefCounted

## The trip of the Soul Mole's rock and the Soul Wind's funnel for its SpellCarrier: it walks the
## ground from the wizard to a soul in half of `roundtrip_s`, turns there (`reached`), and comes
## back in the other half. It ends when the soul is gone or no longer waiting. It moves the carrier
## it is given and nothing else: who takes the soul is SoulFetch, who is stunned on the way is
## CarrierPulse. At the turn it also sets the carrier's `phase` to LEAVING, which is replicated, so
## every peer can tell the rock took the soul.

var _carrier: SpellCarrier
var _turn := Vector3.ZERO
var _side := Vector3.ZERO


func _init(carrier: SpellCarrier) -> void:
	_carrier = carrier


## One tick of the trip. Server or solo.
func step() -> void:
	var leg := MatchClock.ticks_for(_carrier.roundtrip_s) / 2
	var target := _carrier.soul()
	var owner_body := _carrier.wizard()
	if (
		target == null
		or owner_body == null
		or not (target.state == Soul.State.NORMAL or target.state == Soul.State.EMERGING)
	):
		_carrier.stop()
		return
	_carrier.frame += 1
	if _carrier.frame == leg + 1:
		_turn = _carrier.global_position
		_carrier.phase = SpellCarrier.Phase.LEAVING
		_carrier.reached.emit(target)
	var soul_at := target.global_position
	if _carrier.frame == 1:
		_side = CarrierPath.side_velocity(_carrier.start, soul_at, _carrier.bend)
	if _carrier.frame <= leg:
		_carrier.global_position = _grounded(
			CarrierPath.out_at(_carrier.start, soul_at, _side, _carrier.frame, leg)
		)
	else:
		_carrier.global_position = _grounded(
			CarrierPath.back_at(_turn, owner_body.global_position, _side, _carrier.frame - leg, leg)
		)
	if _carrier.frame >= MatchClock.ticks_for(_carrier.roundtrip_s):
		_carrier.stop()


## The same place, on the ground (a carrier walks it).
func _grounded(at: Vector3) -> Vector3:
	var y := GroundRay.surface_y(
		_carrier, at, _carrier.ground_mask, GroundRay.wizard_rids(_carrier.get_tree()), NAN
	)
	return at if is_nan(y) else Vector3(at.x, y, at.z)
