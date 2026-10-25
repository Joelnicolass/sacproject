@tool
extends EditorPlugin
## 055s s0 (disposable): registers the probe export plugin when the editor (also the headless export) enables the addon.

var _export_plugin := preload("res://addons/s0_strip/strip.gd").new()


func _enter_tree() -> void:
	print("S0 export plugin enter_tree (editor plugin enabled in the headless export)")
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
