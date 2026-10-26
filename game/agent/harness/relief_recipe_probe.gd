extends SceneTree

## RFC-067 P6: bakes one albedo with several ReliefRecipe variants (strength x smoothing) into PNGs, so the foliage recipe is
## picked by measuring (tools/look/measure_mottle.py), not by eye. Writes nothing under scenes/ or assets/.
##   Godot --headless --path . --script res://agent/harness/relief_recipe_probe.gd -- [--albedo=res://...png] [--out=res://agent/out/surface_batch/foliage_probe]

const STRENGTHS: Array[float] = [2.5, 1.5, 1.0]
const SMOOTHINGS: Array[int] = [0, 1, 2]

var _albedo := "res://assets/original/textures/JAW1/plant.png"
var _out := "res://agent/out/surface_batch/foliage_probe"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--albedo="):
			_albedo = arg.trim_prefix("--albedo=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var image := Image.load_from_file(ProjectSettings.globalize_path(_albedo))
	for strength in STRENGTHS:
		for smoothing in SMOOTHINGS:
			var recipe := ReliefRecipe.new()
			recipe.strength = strength
			recipe.smoothing = smoothing
			var name := "s%.1f_m%d" % [strength, smoothing]
			(ReliefBaker.bake(image, recipe).normal as Image).save_png("%s/%s.png" % [_out, name])
			print("RELIEF_PROBE wrote ", name)
	quit()
