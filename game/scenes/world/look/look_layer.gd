@tool
class_name LookLayer
extends Node3D

## Contract of one look layer (a child of `LookRig/Layers`). The rig hands it the profile and the
## quality preset; hiding the layer turns it off (`restore`). Layers know nothing of each other.
## Presentation only: the rig is freed in a dedicated or headless process, so none of this runs there.


## Show this profile (null = classic mode: put everything back). Reads `rig.quality_preset`.
func apply_look(_profile: LookProfile, _rig: LookRig) -> void:
	pass


## The quality preset changed (shadows, SSAO, SSIL, ...). Null = engine defaults.
func apply_quality(_preset: LookQuality) -> void:
	pass
