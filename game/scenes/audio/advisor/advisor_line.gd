@tool
class_name AdvisorLine
extends Resource

## One thing the advisor can say: the voice clip, how important it is and how long it stays quiet after being said. A type
## template (embedded in advisor.tscn, never written at runtime). It does not decide when it is said: AdvisorWatch (the
## game's warnings) and AdvisorVoice.refusal_lines (the refusals) hold the lines they say.
## The `resource_name` is its name in the SoundLog (emitter) and in the queue: keep it unique in the advisor.

enum Priority {
	## A refusal, a repeated nag: waits its turn.
	ANNOY,
	## Something happened to you: cuts an ANNOY line.
	IMPORTANT,
	## The altar or a building is in danger: cuts everything below it.
	CRUCIAL,
}

## The clip (bus Voice).
@export var cue: SoundCue
@export var priority: Priority = Priority.ANNOY
## Game seconds this line stays quiet after its event (each event pushes the quiet on: a fight that goes on says «under
## attack» once).
@export_range(0.0, 60.0, 0.1, "suffix:s") var quiet_s := 2.0


## Its name for the queue and the log.
func id() -> StringName:
	return StringName(resource_name) if not resource_name.is_empty() else StringName("line_%d" % get_instance_id())


## True when it has a clip with a stream.
func is_audible() -> bool:
	return cue != null and not cue.is_silent()
