class_name WarmHook
extends Node

## A plug for the warm-up: while the loading screen is up, ShaderWarmup asks every hook (`asked`) to
## draw for a moment what only its owner can show (pooled bursts and bolts, the rain and the snow,
## the swarms of the air, a body's blink). Drop one in the owner's scene and connect `asked` to the
## owner's method there; the owner draws at `stage` (in front of the match camera), plays no sound,
## shakes nothing and tells nobody.
## What it does not do: draw anything itself, know who asks, or run when no warm-up asks (the
## dedicated server never does).

## The warm-up asks to draw now, at `stage`.
signal asked(stage: Node3D)

## Every hook is in this group while it is in the tree; ShaderWarmup asks them all.
const GROUP := &"warm_hooks"


func _enter_tree() -> void:
	add_to_group(GROUP)


## ShaderWarmup calls this once per warm-up.
func ask(stage: Node3D) -> void:
	asked.emit(stage)
