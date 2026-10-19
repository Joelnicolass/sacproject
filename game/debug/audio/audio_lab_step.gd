@tool
class_name AudioLabStep
extends Resource

## RFC-052 (F360+): one step of an AudioLabScript: the lab does `action` on the node `target`, then checks the SoundLog for
## `event` of that emitter. Lab only (debug/audio/).

enum Expect {
	## A played entry of `event` must appear.
	PLAYED,
	## No played entry of `event` may appear (the per-body limit, a body with no set).
	SILENT,
	## PLAYED when the emitter has a cue for `event` right now (the original's sets are there), else SILENT: the same step
	## passes with and without the original's audio.
	IF_SET,
}

## Node of the lab (path from its root): "Original", "Custom", "Wizard"; "." for the FX actions; "Fountain", "Altar".
@export var target: NodePath
## What the lab does: summon, swing, shoot, damaged, death (units); cast, damaged, death, ghost (the wizard);
## fx, puff, beam, scene (FxBus with `arg`, 052d); spawn (`arg` a projectile scene, 052d); loop, occupy, release (the
## target's SoundEmitter3D loops; a manafount's Manalith on and off, 052d).
@export var action: StringName
## The action's argument: an FX name, a beam type, a scene path.
@export var arg := ""
## The emitter the log entry must have; empty = the target's node name (an FX sounds as its FX name).
@export var emitter: StringName
## The SoundEvent the step looks for in the log.
@export var event: StringName
@export var expect: Expect = Expect.PLAYED
## Game seconds the lab waits before the action (the limit of `damaged` is 1.5 s).
@export_range(0.0, 10.0, 0.1, "suffix:s") var wait_s := 0.0
