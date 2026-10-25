class_name MpInterpolator
extends RefCounted

## A short history of a proxy's server states (stamp, position, rotation) and where to draw it at a given time:
## between the two states around that time, so uneven packet arrival never shows as stutter. Past the newest state
## it keeps going a little (`max_extrapolate_s`) and then waits. Pure data: no tree, no network.
## Not: prediction of the owner's own node (MpPredictor), the exponential follow (MpSmoother).

const CAPACITY := 32

var max_extrapolate_s: float = 0.1

var _stamps: PackedFloat64Array = PackedFloat64Array()
var _positions: PackedVector3Array = PackedVector3Array()
var _rotations: Array[Quaternion] = []


func size() -> int:
	return _stamps.size()


func clear() -> void:
	_stamps.clear()
	_positions.clear()
	_rotations.clear()


## A state from the server. Older or repeated stamps are ignored (an unreliable packet out of order).
func push(stamp: float, position: Vector3, rotation: Quaternion) -> void:
	if not _stamps.is_empty() and stamp <= _stamps[_stamps.size() - 1]:
		return
	_stamps.append(stamp)
	_positions.append(position)
	_rotations.append(rotation)
	if _stamps.size() > CAPACITY:
		_stamps.remove_at(0)
		_positions.remove_at(0)
		_rotations.remove_at(0)


func newest_stamp() -> float:
	return _stamps[_stamps.size() - 1] if not _stamps.is_empty() else 0.0


## [position, rotation] to draw at `time` (server clock). Call only with size() > 0.
func sample(time: float) -> Array:
	var last := _stamps.size() - 1
	if time <= _stamps[0]:
		return [_positions[0], _rotations[0]]
	if time >= _stamps[last]:
		if last == 0:
			return [_positions[last], _rotations[last]]
		var span := _stamps[last] - _stamps[last - 1]
		var ahead := minf(time - _stamps[last], max_extrapolate_s)
		var velocity := (_positions[last] - _positions[last - 1]) / maxf(span, 0.0001)
		return [_positions[last] + velocity * ahead, _rotations[last]]
	var i := last - 1
	while i > 0 and _stamps[i] > time:
		i -= 1
	var t := (time - _stamps[i]) / maxf(_stamps[i + 1] - _stamps[i], 0.0001)
	return [_positions[i].lerp(_positions[i + 1], t), _rotations[i].slerp(_rotations[i + 1], t)]
