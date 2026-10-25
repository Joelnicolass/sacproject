class_name ClipFacts
extends RefCounted

## What the rules need to know about a model's clips: how long each role lasts, in frames and seconds, and the frame where its
## blow lands (`hit`) or its shot leaves (`shoot`). Read once from the model's AnimationLibrary and kept; nothing here plays or
## draws a clip, and nothing asks the library again per frame.
## The library is the single source: the body draws it and the rules read these numbers (the dedicated server loads the library
## without the meshes).

const DEFAULT_FPS := 30
const HIT := "hit"
const SHOOT := "shoot"

## One ClipFacts per library, built the first time somebody asks.
static var _cache: Dictionary[AnimationLibrary, ClipFacts] = {}

var _frames: Dictionary[StringName, int] = {}
var _fps: Dictionary[StringName, int] = {}
var _seconds: Dictionary[StringName, float] = {}
var _hits: Dictionary[StringName, PackedInt32Array] = {}
var _shots: Dictionary[StringName, PackedInt32Array] = {}


## The facts of `library` (built once and shared). An empty one for null.
static func of(library: AnimationLibrary) -> ClipFacts:
	if library == null:
		return ClipFacts.new()
	if not _cache.has(library):
		_cache[library] = ClipFacts.new()._read(library)
	return _cache[library]


## True when the library has a clip for `role`.
func has(role: StringName) -> bool:
	return _frames.has(role)


## Frames of the clip at its own frame rate; 0 without the role.
func frames(role: StringName) -> int:
	return _frames.get(role, 0)


## Frames per second the clip was authored at (30 for most; the Spitfire's shots are slower).
func fps(role: StringName) -> int:
	return _fps.get(role, DEFAULT_FPS)


## How long the clip lasts, exactly frames / fps; 0 without the role.
func seconds(role: StringName) -> float:
	return _seconds.get(role, 0.0)


## The frames (at the clip's rate) where each blow of the clip lands, in order. Empty: the clip has no `hit` marker.
func hits(role: StringName) -> PackedInt32Array:
	return _hits.get(role, PackedInt32Array())


## The frames where each shot of the clip leaves, in order. Empty: the clip has no `shoot` marker.
func shots(role: StringName) -> PackedInt32Array:
	return _shots.get(role, PackedInt32Array())


func _read(library: AnimationLibrary) -> ClipFacts:
	for name in library.get_animation_list():
		var role := StringName(name)
		var anim := library.get_animation(role)
		var rate := roundi(1.0 / anim.step) if anim.step > 0.0 else DEFAULT_FPS
		_fps[role] = rate
		_frames[role] = roundi(anim.length * rate)
		_seconds[role] = anim.length
		_hits[role] = _marker_frames(anim, HIT, rate)
		_shots[role] = _marker_frames(anim, SHOOT, rate)
	return self


## Frames of the markers `base`, `base2`, `base3`... in that order.
static func _marker_frames(anim: Animation, base: String, rate: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var index := 1
	while true:
		var marker := StringName(base if index == 1 else "%s%d" % [base, index])
		if not anim.has_marker(marker):
			break
		out.append(roundi(anim.get_marker_time(marker) * rate))
		index += 1
	return out
