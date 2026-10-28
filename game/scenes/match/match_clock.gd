class_name MatchClock
extends RefCounted

## The ticks of the match in this process. The one owner of simulation time: whatever falls due
## (cooldowns, deadlines, lifetimes) is measured against now(), never against the render delta.
## MatchWorld (the root of match.tscn) calls begin() from _enter_tree on every peer, before MatchSeed.begin. SceneTree.physics_frame is emitted
## once per physics step before any _physics_process (and also while the tree is paused), so the count does not depend
## on the order of the nodes; it only advances when the tree is not paused. Without MatchWorld (debug scenes) now()
## hooks itself lazily on the first read.

## Ticks per second of the simulation: the project's physics/common/physics_ticks_per_second (read once at class load).
static var TICKS_PER_SECOND: int = Engine.physics_ticks_per_second
## The same, as a float: the per-tick formulas divide by it (an int there would be an integer division).
static var TICKS_PER_SECOND_F: float = float(Engine.physics_ticks_per_second)

static var _ticks := 0
static var _tree: SceneTree


## Starts the count at 0 and hooks `tree` (once: a second begin only resets the count).
static func begin(tree: SceneTree) -> void:
	_ticks = 0
	_hook(tree)


## Ticks of the match since begin() (or since the lazy hook).
static func now() -> int:
	if _tree == null:
		_hook(Engine.get_main_loop() as SceneTree)
	return _ticks


## Whole ticks that cover `seconds` (frames of 1/60 s). 0.5 s → 30; 0.501 s → 31.
static func ticks_for(seconds: float) -> int:
	return maxi(0, ceili(seconds * TICKS_PER_SECOND - 1e-4))


static func _hook(tree: SceneTree) -> void:
	if tree == null:
		return
	var step := _on_physics_frame
	if _tree != null and _tree != tree and _tree.physics_frame.is_connected(step):
		_tree.physics_frame.disconnect(step)
	_tree = tree
	if not tree.physics_frame.is_connected(step):
		tree.physics_frame.connect(step)


static func _on_physics_frame() -> void:
	if _tree != null and not _tree.paused:
		_ticks += 1
