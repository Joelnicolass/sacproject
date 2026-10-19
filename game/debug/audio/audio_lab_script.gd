@tool
class_name AudioLabScript
extends Resource

## RFC-052 (F360+): what the audio lab (debug/audio/f360_audio_lab.tscn) runs: one .tres per cut (lab_<cut>.tres), not
## another .gd. `roots` go before SoundLibrary's own (the fixture sets that sound without the original).

@export var cut := ""
## Searched first (SoundLibrary.roots); with `--audio-no-original` they are the only ones (plus an empty root).
@export var roots: PackedStringArray = []
@export var steps: Array[AudioLabStep] = []
