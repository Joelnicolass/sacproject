class_name MpInputFrame
extends RefCounted

## The input of one player in one physics tick, as it travels to the server. Pure data: no tree, no network.
## Not: reading the keyboard (MpInput does) or deciding what an action does (the actor does).
##
## Presses and releases are counters that only grow, so a press is never lost when a packet is: the server
## sees the counter jump and reports one "just pressed" tick. `seq` grows by one per tick the owner sampled.

## Most custom values (aim, cursor...) one frame may carry, and their largest encoded size accepted from a client.
const MAX_VALUES := 16
const MAX_BYTES := 1024

var seq: int = 0
var strengths: PackedFloat32Array = PackedFloat32Array()
var presses: PackedInt32Array = PackedInt32Array()
var releases: PackedInt32Array = PackedInt32Array()
var values: Dictionary = {}
## The server time this player was seeing when it sampled the frame (its proxies are drawn that far back): lag
## compensation rewinds the others to it. 0 = unknown (an older client).
var view: float = 0.0


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
	frame.view = view
	return frame


## A strength as the byte it travels as (MpInputPacket): 0..255.
static func quantize_byte(strength: float) -> int:
	return clampi(roundi((0.0 if is_nan(strength) else strength) * 255.0), 0, 255)


## Strengths are kept as they travel (1/255 steps), so the owner predicts with exactly what the server gets.
func record(index: int, strength: float, just_pressed: bool, just_released: bool) -> void:
	strengths[index] = quantize_byte(strength) / 255.0
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
