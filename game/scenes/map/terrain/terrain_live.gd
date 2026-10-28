class_name TerrainLive
extends Node

## The stamps playing on the ground, gathered once per physics tick. `put` and `drop` (what
## Terrain.stamp and Terrain.unstamp ask) only note the last request of each stamp; at the tick it
## works out the new shift of every stamp that moved by at least `min_step_m` and tells `ticked`
## once, with those shifts and the stamps that ended. Terrain, the one writer of the ground, applies
## them. Not: the sums (GroundField), what stays (Terrain.keep_stamp), the network (each peer plays
## its own).

## Once per tick with something to show: the new shift of each stamp that moved and the keys of the
## stamps that ended.
signal ticked(shifts: Array, ended: PackedStringArray)

## A stamp is drawn again only when its height moved by this many metres, or its ring travelled this
## far (a slow decline is not redrawn every tick).
@export_range(0.0, 2.0, 0.01, "suffix:m") var min_step_m := 0.1

## How much a stamp may move each lattice vertex (PinRules.weights: 0 under a base); empty = all of
## it. Terrain sets it once.
var pins := PackedFloat32Array()


## One stamp's shift for this tick: `values` row by row over the lattice vertices of `rect`.
class Shift:
	var key: String
	var rect: Rect2i
	var values: PackedFloat32Array


## The last thing a stamp asked to show, and what it showed last.
class Request:
	var profile: StampProfile
	var center: Vector2
	var reach_m: float
	var peak_m: float
	var at_s: float
	var pattern: PackedFloat32Array
	var due := false
	var shown_share := INF
	var shown_ring := INF
	var shown_center := Vector2(INF, INF)


var _requests := {}  ## key -> Request, for every stamp playing
var _ended := PackedStringArray()
var _due := 0


## Stamp `key` shows its shift at `at_s` s of its profile (in place of its last one) from the next
## tick.
func put(
	key: String,
	profile: StampProfile,
	center: Vector2,
	reach_m: float,
	peak_m: float,
	at_s: float,
	pattern: PackedFloat32Array
) -> void:
	var request: Request = _requests.get(key)
	if request == null:
		request = Request.new()
		_requests[key] = request
	var index := _ended.find(key)
	if index >= 0:
		_ended.remove_at(index)
	request.profile = profile
	request.center = center
	request.reach_m = reach_m
	request.peak_m = peak_m
	request.at_s = at_s
	request.pattern = pattern
	if not request.due:
		request.due = true
		_due += 1


## Stamp `key` is over: the next tick takes its shift away.
func drop(key: String) -> void:
	forget(key)
	_ended.append(key)


## Stamp `key` is gone already (its end was kept for good): nothing of it is shown or taken away
## again.
func forget(key: String) -> void:
	var request: Request = _requests.get(key)
	if request != null and request.due:
		_due -= 1
	_requests.erase(key)
	var index := _ended.find(key)
	if index >= 0:
		_ended.remove_at(index)


func _physics_process(_delta: float) -> void:
	if _due == 0 and _ended.is_empty():
		return
	var shifts: Array[Shift] = []
	for key: String in _requests:
		var request: Request = _requests[key]
		if request.due:
			request.due = false
			var shift := _shift_of(key, request)
			if shift != null:
				shifts.append(shift)
	_due = 0
	var ended := _ended
	_ended = PackedStringArray()
	if not shifts.is_empty() or not ended.is_empty():
		ticked.emit(shifts, ended)


## The shift `request` shows now, or null when it moved less than `min_step_m` (or a picture stamp
## has no pattern yet).
func _shift_of(key: String, request: Request) -> Shift:
	var profile := request.profile
	var share := profile.timeline.sample(request.at_s)
	var ring := profile.ring_travel.sample(request.at_s) if profile.is_ring() else 0.0
	if (
		absf((share - request.shown_share) * request.peak_m) < min_step_m
		and absf(ring - request.shown_ring) < min_step_m
		and request.center == request.shown_center
	):
		return null
	var shift := Shift.new()
	shift.key = key
	shift.rect = TerrainGrid.vertex_rect(request.center, request.reach_m)
	shift.values = StampRules.shift(
		profile,
		request.center,
		request.reach_m,
		request.peak_m,
		request.at_s,
		shift.rect,
		request.pattern
	)
	if shift.values.size() != shift.rect.get_area():
		return null
	PinRules.apply(shift.values, shift.rect, pins)
	request.shown_share = share
	request.shown_ring = ring
	request.shown_center = request.center
	return shift
