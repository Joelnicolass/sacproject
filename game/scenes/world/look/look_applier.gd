class_name LookApplier
extends RefCounted

## Hands a LookProfile to the world's LookRig. ThemeApplier calls it after the classic look
## (a theme with `look = null` never gets here). The rig owns the layers; this knows none.

const LOOK_DIR := "res://data/look"
const RIG_NODE := ^"Look"


static func profile_for(god: StringName) -> LookProfile:
	var path := LOOK_DIR.path_join("%s.tres" % god)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as LookProfile


## A null profile is the classic mode: layers put the classic look back.
static func apply(profile: LookProfile, world_root: Node) -> void:
	var rig := world_root.get_node_or_null(RIG_NODE)
	if rig and rig.has_method("apply_profile"):
		rig.call("apply_profile", profile)
