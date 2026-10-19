@tool
class_name AudioLabScript
extends Resource

## RFC-052 (F360+): what the audio lab (debug/audio/f360_audio_lab.tscn) runs: one .tres per cut (lab_<cut>.tres), not
## another .gd. `roots` go before SoundLibrary's own (the fixture sets that sound without the original).

@export var cut := ""
## Searched first (SoundLibrary.roots); with `--audio-no-original` they are the only ones (plus an empty root).
@export var roots: PackedStringArray = []
## Searched last, after SoundLibrary's own (or after the empty root with `--audio-no-original`): fixtures that stand in only
## for what the original lacks (052e: the advisor and a creature's voices), so a run with the original still hears its sets.
@export var fallback_roots: PackedStringArray = []
@export var steps: Array[AudioLabStep] = []
