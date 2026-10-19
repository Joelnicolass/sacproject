extends SceneTree

## F335: draws (or redraws) the HUD icon of a creature of your own, assets/custom/icons/<tag>.png, from its model. It needs a window (a
## headless Godot has no renderer); it ends by itself after a few frames. tools/bake/new_creature.gd does the same when it runs with one.
##
##   Godot --path . --script res://tools/bake/creature_icon.gd -- testmonster [--force] [--clip=<idle clip>]
##
## A PNG that is already there is kept (it may be your own) unless `--force`. Without `--clip` the idle clip of the creature's .tres is used.

var _started := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var tag := ""
	var force := false
	var clip := ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--force":
			force = true
		elif arg.begins_with("--clip="):
			clip = arg.get_slice("=", 1)
		elif not arg.begins_with("--") and tag.is_empty():
			tag = arg.get_file().get_basename()
	if tag.is_empty():
		push_error("creature_icon: pass the model tag: ... --script res://tools/bake/creature_icon.gd -- testmonster")
		quit(1)
		return
	if clip.is_empty():
		var type := load("res://data/catalog/creatures/%s.tres" % tag) as CreatureType
		clip = str(type.idle_animation.get("tag", "")) if type != null else ""
	var result := await CreatureIconRender.ensure(root, tag, clip, force)
	print("CREATURE_ICON %s: %s" % [tag, result])
	quit(1 if result.begins_with("not drawn") else 0)
