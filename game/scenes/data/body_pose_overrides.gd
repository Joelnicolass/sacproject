@tool
class_name BodyPoseOverrides
extends Resource

## The list of corrections BodyCatalog applies over the baked models.
## data/bodies/pose_overrides.tres is the committed instance. Editing an entry in the inspector
## emits `changed` here too, so every BodyVisual in an open scene redraws.

@export var entries: Array[BodyPoseOverride] = []:
	set(value):
		for old in entries:
			if old and old.changed.is_connected(emit_changed):
				old.changed.disconnect(emit_changed)
		entries = value
		for entry in entries:
			if entry and not entry.changed.is_connected(emit_changed):
				entry.changed.connect(emit_changed)
		emit_changed()


## The entry for a model, or null. The last one wins if a tag is repeated.
func find(model: String) -> BodyPoseOverride:
	for index in range(entries.size() - 1, -1, -1):
		var entry := entries[index]
		if entry and entry.model == model:
			return entry
	return null

