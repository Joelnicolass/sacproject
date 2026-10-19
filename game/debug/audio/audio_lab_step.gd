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

## Node of the lab (path from its root): "Original", "Custom", "Wizard"; "." for the FX actions; "Fountain", "Altar";
## "Building" (052e).
@export var target: NodePath
## What the lab does: summon, swing, shoot, damaged, death (units); cast, damaged, death, ghost (the wizard);
## fx, puff, beam, scene (FxBus with `arg`, 052d); spawn (`arg` a projectile scene, 052d); loop, occupy, release (the
## target's SoundEmitter3D loops; a manafount's Manalith on and off, 052d); select (the target alone in the Selection),
## order (`arg` a command of Orders.requested for the target), refuse (`arg` a Refusal key said on the CommandLog), hit (a
## tenth of the target's Health off: a building), ritual (`arg` desecrate: a Desecrate on the local altar starts; complete:
## the lab's ritual ends completed; 052f also convert: a Convert near the camera), 052e.
## 052f (target MusicDirector, emitter `music`, event = the mood): music (`arg` restart: forget the mood and look; look:
## look now), battle (CombatGauge.force(`arg` or 1)), result (`arg` won: the lab's MatchState ends with the local side
## winning), god (`arg` a god: its set). The wizard's `damaged` also feeds the gauge (the 120 s rule).
## 052g (target AmbienceDirector, emitter `ambience`): bed (the bed again, event `bed`), ambient (a one-shot now, event
## `ambient`), god (`arg` a god: its set and its bed), wait (nothing: with `from_wait`, what the director did on its own).
@export var action: StringName
## The action's argument: an FX name, a beam type, a scene path.
@export var arg := ""
## The emitter the log entry must have; empty = the target's node name (an FX sounds as its FX name; an advisor line as
## its code, event `advice`).
@export var emitter: StringName
## The SoundEvent the step looks for in the log.
@export var event: StringName
@export var expect: Expect = Expect.PLAYED
## Game seconds the lab waits before the action (the limit of `damaged` is 1.5 s).
@export_range(0.0, 60.0, 0.1, "suffix:s") var wait_s := 0.0
## Look at the log from before the wait, not from the action: what a director did on its own while the lab waited (the
## battle that ends after `hold_s`, a one-shot of the ambience's interval), 052f.
@export var from_wait := false
## 052i: with PLAYED, the stream of the entry must contain this text (`testmonster/swing_1.wav`: the file a bake took).
@export var stream_has := ""
