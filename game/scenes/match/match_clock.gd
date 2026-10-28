class_name MatchClock
extends Node

## The ticks of the running match: the one owner of simulation time. Whatever falls due (cooldowns, deadlines,
## lifetimes) is measured against now(), never against the render delta. It is the node `Context/Clock` of match.tscn:
## MatchWorld calls begin() from its _enter_tree on every peer (before the map is instantiated) and the count runs until
## this node leaves the tree (`Context` is the first child of the world, so it leaves last: a body that leaves still reads
## the match's time). SceneTree.physics_frame is emitted
## once per physics step before any _physics_process (and also while the tree is paused), so the count does not depend
## on the order of the nodes; it only advances when the tree is not paused.
## The static functions are the way everybody reads it (hundreds of callers): they forward to the clock in the tree.
## Without a match (the editor, F6 on one scene) now() is the engine's physics frame count.

## Ticks per second of the simulation: the project's physics/common/physics_ticks_per_second (read once at class load;
## a project setting, the same for every match).
static var TICKS_PER_SECOND: int = Engine.physics_ticks_per_second
## The same, as a float: the per-tick formulas divide by it (an int there would be an integer division).
static var TICKS_PER_SECOND_F: float = float(Engine.physics_ticks_per_second)

## The clock of the running match (set by begin, cleared in _exit_tree); null = no match.
static var _live: MatchClock

var _ticks := 0
var _tree: SceneTree


## Starts the count at 0 on `tree` and makes this the clock everybody reads.
func begin(tree: SceneTree) -> void:
	_ticks = 0
	_tree = tree
	_live = self
	if not tree.physics_frame.is_connected(_on_physics_frame):
		tree.physics_frame.connect(_on_physics_frame)


func _exit_tree() -> void:
	if _tree != null and _tree.physics_frame.is_connected(_on_physics_frame):
		_tree.physics_frame.disconnect(_on_physics_frame)
	if _live == self:
		_live = null


## Ticks of the running match since begin().
static func now() -> int:
	return _live._ticks if _live != null else Engine.get_physics_frames()


## Whole ticks that cover `seconds` (frames of 1/60 s). 0.5 s → 30; 0.501 s → 31.
static func ticks_for(seconds: float) -> int:
	return maxi(0, ceili(seconds * TICKS_PER_SECOND - 1e-4))


func _on_physics_frame() -> void:
	if not _tree.paused:
		_ticks += 1
