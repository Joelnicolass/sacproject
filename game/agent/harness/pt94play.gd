extends Node

## Observation only (F94 playtest, corte 028c): the local wizard is spawned with a runtime name, so these read
## it from the "local_wizard" group and hand it to pt94_clips. Moves nothing and sets nothing.
##   wizard_rate(3.0)  starts pt94_clips' clip-frame count on the local wizard; pt94_clips.rate_report() prints it
##   wizard_clip()     name, walking flag and clip role/tag/frame of the local wizard


func _wizard() -> Node:
	return get_tree().get_first_node_in_group("local_wizard")


func wizard_rate(seconds: float) -> String:
	var wizard := _wizard()
	var clips := get_parent().get_node_or_null("pt94_clips")
	if wizard == null or clips == null:
		return "sin mago o sin pt94_clips"
	return "%s: %s" % [wizard.name, clips.clip_rate(String(wizard.name), seconds)]


func wizard_clip() -> String:
	var wizard := _wizard()
	if wizard == null:
		return "sin mago"
	var info: Dictionary = wizard.debug_clip_info() if wizard.has_method("debug_clip_info") else {}
	return "%s walking=%s role=%s tag=%s frame=%d" % [wizard.name, wizard.is_walking() if wizard.has_method("is_walking") else "-",
		info.get("role", ""), info.get("tag", ""), int(info.get("frame", 0))]
