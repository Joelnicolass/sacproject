class_name MpInputFrame
extends RefCounted

## The input of one player in one physics tick, as it travels to the server. Pure data: no tree, no network.
## Not: reading the keyboard (MpInput does) or deciding what an action does (the actor does).
##
## Presses and releases are counters that only grow, so a press is never lost when a packet is: the server
## sees the counter jump and reports one "just pressed" tick. `seq` grows by one per tick the owner sampled.

## Most custom values (aim, cursor...) one frame may carry, and the largest packed size accepted from a client.
const MAX_VALUES := 16
const MAX_BYTES := 1024

var seq: int = 0
var strengths: PackedFloat32Array = PackedFloat32Array()
var presses: PackedInt32Array = PackedInt32Array()
var releases: PackedInt32Array = PackedInt32Array()
var values: Dictionary = {}


static func sized(count: int) -> MpInputFrame:
	var frame := MpInputFrame.new()
	frame.strengths.resize(count)
	frame.presses.resize(count)
	frame.releases.resize(count)
	return frame


## The next tick, starting from this one: same counters and values, new seq.
func next() -> MpInputFrame:
	var frame := MpInputFrame.new()
	frame.seq = seq + 1
	frame.strengths = strengths.duplicate()
	frame.presses = presses.duplicate()
	frame.releases = releases.duplicate()
	frame.values = values.duplicate()
	return frame


func record(index: int, strength: float, just_pressed: bool, just_released: bool) -> void:
	strengths[index] = clampf(strength, 0.0, 1.0)
	if just_pressed:
		presses[index] += 1
	if just_released:
		releases[index] += 1


## Action `index` was pressed at least once between `older` and this frame (lost packets included).
func pressed_since(older: MpInputFrame, index: int) -> bool:
	return presses[index] > older.presses[index]


func released_since(older: MpInputFrame, index: int) -> bool:
	return releases[index] > older.releases[index]


## Same input as `other` (seq aside): nothing new to send.
func same_as(other: MpInputFrame) -> bool:
	return other != null and strengths == other.strengths and presses == other.presses \
		and releases == other.releases and values == other.values


func pack() -> Array:
	return [seq, strengths, presses, releases, values]


## A frame from a packet, or null if it does not fit `count` actions (a broken or hostile client).
static func unpack(data: Array, count: int) -> MpInputFrame:
	if data.size() != 5 or var_to_bytes(data).size() > MAX_BYTES:
		return null
	if typeof(data[0]) != TYPE_INT or typeof(data[1]) != TYPE_PACKED_FLOAT32_ARRAY:
		return null
	if typeof(data[2]) != TYPE_PACKED_INT32_ARRAY or typeof(data[3]) != TYPE_PACKED_INT32_ARRAY:
		return null
	if typeof(data[4]) != TYPE_DICTIONARY:
		return null
	var frame := MpInputFrame.new()
	frame.seq = data[0]
	frame.strengths = data[1]
	frame.presses = data[2]
	frame.releases = data[3]
	frame.values = data[4]
	if frame.strengths.size() != count or frame.presses.size() != count or frame.releases.size() != count:
		return null
	if frame.values.size() > MAX_VALUES:
		return null
	for i in count:
		var s := frame.strengths[i]
		frame.strengths[i] = 0.0 if is_nan(s) else clampf(s, 0.0, 1.0)
	return frame
