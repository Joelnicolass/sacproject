extends SceneTree

## c1-0 probe, question 4 (disposable): reads what Godot's own .glb import did on the copy that run_import_probe.sh imports with the
## native per-animation options (save_to_file + keep_custom_tracks, and a slice named after a role). Reports whether the importer
## can write one .res per clip, whether a slice can carry a role name, whether the saved .res keeps every key, and whether it
## has markers or method tracks (the importer has no option for them).
## "$GODOT" --headless --path game --script res://debug/creatures/c1_0/c1_0_import_check.gd
## Prints C1_0 import ..., C1_0 VERDICT import ... (exit 0) or C1_0 FAIL <reason> (exit 1).

const Common := preload("res://debug/creatures/c1_0/c1_0_common.gd")
const DIR := "res://debug/creatures/c1_0/tmp/"
const SCENE := DIR + "eorc_split.glb"
## The clip the import options are set on and the role name of its slice (see run_import_probe.sh).
const CLIP := "HUa1"
const ROLE := "attack"

var _all_keys := false


func _initialize() -> void:
	Common.arm_watchdog(self)
	_main()


func _main() -> void:
	var packed := load(SCENE) as PackedScene
	if packed == null:
		Common.fail(self, "the copy was not imported: " + SCENE)
		return
	var inst := packed.instantiate()
	var found := inst.find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		inst.free()
		Common.fail(self, "the imported copy has no AnimationPlayer (a LFS pointer, not the real .glb?)")
		return
	var player := found[0] as AnimationPlayer
	var names := player.get_animation_list()
	print("C1_0 import scene_animations=%d has_%s=%s has_%s=%s" % [names.size(), CLIP, player.has_animation(CLIP), ROLE, player.has_animation(ROLE)])
	var scene_keys := Common.track_stats(player.get_animation(CLIP)).y if player.has_animation(CLIP) else -1
	var whole := _report_file(CLIP, scene_keys)
	var sliced := _report_file(ROLE, scene_keys)
	var sliced_by_role := player.has_animation(ROLE) or sliced
	print("C1_0 import options: %s" % _options())
	print("C1_0 VERDICT import save_to_file=%s slice_named_by_role=%s keeps_all_keys=%s markers_from_import=NO (no such option; needs a post-import script)"
		% ["YES" if whole else "NO", "YES" if sliced_by_role else "NO", "YES" if whole and _all_keys else "NO"])
	inst.free()
	quit(0)


## Loads <DIR><name>.res if the importer wrote it and prints its tracks, keys, markers and method tracks.
func _report_file(clip_name: String, scene_keys: int) -> bool:
	var path := "%s%s.res" % [DIR, clip_name]
	if not ResourceLoader.exists(path):
		print("C1_0 import file=%s exists=false" % path)
		return false
	var anim := load(path) as Animation
	if anim == null:
		print("C1_0 import file=%s exists=true but is not an Animation" % path)
		return false
	var stats := Common.track_stats(anim)
	var methods := 0
	for track in anim.get_track_count():
		if anim.track_get_type(track) == Animation.TYPE_METHOD:
			methods += 1
	if clip_name == CLIP:
		_all_keys = stats.y >= scene_keys and scene_keys > 0
	print("C1_0 import file=%s length=%.4f tracks=%d keys=%d scene_keys=%d markers=%d method_tracks=%d bytes=%d"
		% [path, anim.length, stats.x, stats.y, scene_keys, anim.get_marker_names().size(), methods, Common.file_len(path)])
	return true


## The animation/* lines of the imported copy's .import (what the importer ran with).
func _options() -> String:
	var kept: PackedStringArray = []
	for line in FileAccess.get_file_as_string(SCENE + ".import").split("\n"):
		if line.begins_with("animation/") or line.begins_with("import_script") or line.begins_with("_subresources"):
			kept.append(line.left(160))
	return " | ".join(kept)
