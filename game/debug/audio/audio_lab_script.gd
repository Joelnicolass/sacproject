@tool
class_name AudioLabScript
extends Resource

## RFC-052 (F360+): what the audio lab (debug/audio/f360_audio_lab.tscn) runs: one .tres per cut (lab_<cut>.tres), not
## another .gd. `roots` go before SoundLibrary's own (the fixture sets of the world, the UI, the advisor, the music).

@export var cut := ""
## Searched first (SoundLibrary.roots); with `--audio-no-original` they are the only ones (plus an empty root).
@export var roots: PackedStringArray = []
## Searched last, after SoundLibrary's own (or after the empty root with `--audio-no-original`): fixtures that stand in only
## for what the original lacks (052e: the advisor and a creature's voices), so a run with the original still hears its sets.
@export var fallback_roots: PackedStringArray = []
## The sounds the lab's "Custom" creature has instead of its catalog entry's (fixture streams, so the step does not depend on
## the original). Empty: the creature sounds as its CreatureType says. `custom_set_paths` wins: the first one that exists
## (a set a tool just wrote under user://, then a committed one).
@export var custom_set: SoundSet
@export var custom_set_paths: PackedStringArray = []
## The sounds of the lab's "Wizard" instead of its WizardType's.
@export var wizard_set: SoundSet
@export var steps: Array[AudioLabStep] = []
