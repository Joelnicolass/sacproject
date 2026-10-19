class_name LookApplier
extends RefCounted

## Hands a LookProfile to the world's LookRig. ThemeApplier calls it after the classic look
## (a theme with `look = null` never gets here). The rig owns the layers; this knows none.

const RIG_NODE := ^"Look"


static func profile_for(god: StringName) -> LookProfile:
	var type := GameCatalog.shared().god(String(god))
	return type.load_look() if type != null else null


## A null profile is the classic mode: layers put the classic look back.
static func apply(profile: LookProfile, world_root: Node) -> void:
	var rig := world_root.get_node_or_null(RIG_NODE) as LookRig
	if rig:
		rig.apply_profile(profile)
