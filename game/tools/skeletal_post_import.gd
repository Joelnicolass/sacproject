@tool
extends EditorScenePostImport

## RFC-023b: import script of the skeletal models (assets/original/models/*.glb; export_skeletal.py writes it in each
## .glb.import). The scene importer drops about a third of the keys of every clip (a linear blend of the neighbours
## reproduces them, error up to 0.004 rad) and ignores the per-clip `optimizer/*` options. This puts back the clips as
## the .glb stores them, one key per frame, so the stepped look (nearest key) shows the original's frame.


func _post_import(scene: Node) -> Object:
	var state := GLTFState.new()
	# Constant tracks equal to the rest pose must stay too (a bone a clip does not animate is reset by the rig).
	state.set_additional_data("GLTFRemoveImmutableTracks", false)
	var document := GLTFDocument.new()
	if document.append_from_file(get_source_file(), state) != OK:
		push_error("skeletal_post_import: cannot read %s" % get_source_file())
		return scene
	var raw := document.generate_scene(state)
	var raw_players := raw.find_children("*", "AnimationPlayer", true, false)
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	if raw_players.is_empty() or players.is_empty():
		raw.free()
		return scene
	var raw_player := raw_players[0] as AnimationPlayer
	var player := players[0] as AnimationPlayer
	var library := player.get_animation_library(&"")
	for clip_name in raw_player.get_animation_list():
		var animation := raw_player.get_animation(clip_name).duplicate() as Animation
		# Loop mode and length are the importer's (set per clip in the .import).
		if library.has_animation(clip_name):
			animation.loop_mode = library.get_animation(clip_name).loop_mode
			library.remove_animation(clip_name)
		library.add_animation(clip_name, animation)
	raw.free()
	return scene
