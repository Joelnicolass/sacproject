@tool
extends EditorExportPlugin
## 055s s0 (disposable) copy of what DedicatedStrip must do. Mode from the environment S0_MODE:
##   base   logs what the exporter hands over and changes nothing
##   strip  _customize_resource returns an EMPTY AudioStream / Animation (same class, same length)
##   skip   _export_file calls skip() on the audio files (alternative when _customize_resource does not see them)
## Every line starts with `S0 export`.

var mode := OS.get_environment("S0_MODE")
var _seen := {}


func _get_name() -> String:
	return "S0Strip"


func _begin_customize_resources(_platform: EditorExportPlatform, _features: PackedStringArray) -> bool:
	print("S0 export begin_customize_resources mode=%s" % mode)
	return mode != "skip"


func _get_customization_configuration_hash() -> int:
	return hash(mode)


func _customize_resource(resource: Resource, path: String) -> Resource:
	var key := "%s %s" % [resource.get_class(), path]
	if not _seen.has(key):
		_seen[key] = true
		print("S0 export customize_resource class=%s path=%s" % [resource.get_class(), path])
	if mode != "strip":
		return null
	if resource is AudioStream:
		var empty := ClassDB.instantiate(resource.get_class()) as Resource
		print("S0 export REPLACED %s by an empty %s" % [path, resource.get_class()])
		return empty
	if resource is Animation:
		var src := resource as Animation
		var a := Animation.new()
		a.length = src.length
		a.loop_mode = src.loop_mode
		print("S0 export REPLACED %s (tracks=%d) by an empty Animation length=%s" % [path, src.get_track_count(), str(src.length)])
		return a
	return null


func _export_file(path: String, type: String, _features: PackedStringArray) -> void:
	if path.begins_with("res://clips/") or path.begins_with("res://audio/"):
		print("S0 export export_file path=%s type=%s" % [path, type])
	if mode == "skip" and type.begins_with("AudioStream"):
		skip()
		print("S0 export SKIPPED %s" % path)
