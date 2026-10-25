@tool
class_name AudioLabScript
extends Resource

## What the audio lab (debug/audio/f360_audio_lab.tscn) runs: one .tres per cut (lab_<cut>.tres), not another .gd.

@export var cut := ""
## The sounds the lab's "Custom" creature has instead of its catalog entry's (fixture streams, so the step does not depend on
## the original). Empty: the creature sounds as its CreatureType says. `custom_set_paths` wins: the first one that exists
## (a set a tool just wrote under user://, then a committed one).
@export var custom_set: SoundSet
@export var custom_set_paths: PackedStringArray = []
## The sounds of the lab's "Wizard" instead of its WizardType's.
@export var wizard_set: SoundSet
@export var steps: Array[AudioLabStep] = []
