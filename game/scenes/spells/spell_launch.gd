class_name SpellLaunch
extends Node3D

## What a spell puts into the world while the wizard casts it and lets go of when the casting ends: a chain of bolts, the rocks of a
## halo. LaunchAction makes it when the cast starts (`begin_cast`), calls `release` when the casting time ends and `abort` when the wizard
## is cut. It holds no rule of its own: each kind decides what to do at those three moments. Server (or solo) only; its look reaches
## every peer through FxBus.


## The cast started. `target` is the body the click named (or null), `point` where it was, `cast_ticks` how long the casting lasts.
func begin_cast(
	_wizard: Node3D, _spell: SpellType, _target: Node3D, _point: Vector3, _cast_ticks: int
) -> void:
	pass


## The casting time ended with the wizard alive: let go.
func release(_target: Node3D) -> void:
	pass


## The cast was cut: undo what `begin_cast` made.
func abort() -> void:
	queue_free()


## True while it still acts in the world (LaunchAction refuses a second one when its kind says so).
func is_running() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()
