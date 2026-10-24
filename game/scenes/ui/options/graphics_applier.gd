@tool
class_name GraphicsApplier
extends Node

## RFC-031 031c (F142): puts the player's GraphicsPrefs on screen, at start and live on every change.
## - Only where this node's owner is the running scene: the boot, or the world in a match. A debug scene that
##   instances the world (look_bench, biome_gallery with F6) keeps its own window settings and preset.
## - Window: fullscreen or windowed, VSync and `Engine.max_fps`. An engine flag of this run (`--max-fps`,
##   `--disable-vsync`, `-f`/`--fullscreen`, `-w`/`--windowed`) wins over the preference and is left alone.
## - Quality: `rig.apply_quality(preset)` in a match (the world has a rig; the boot has none), and the «Vegetación»
##   switch: `rig.set_vegetation_enabled` (RFC-054 054f).
## - Inert in everything (window and preset) in the editor, in a headless process, in the dedicated server and under
##   AgentKit (`--agent=…` in the user args): user://settings.cfg is shared by the player and the agents' runs, so a
##   test never inherits the player's choice (no VSync off / no cap in a playtest). The rule is UserSettings.sandboxed():
##   `--user-settings=user://<file>.cfg` (a playtest of the preferences) turns it back on with that file; the engine
##   flags of the run still win.
## - Under AgentKit with a window (not headless) the preset is still applied, deterministically and without touching the
##   player's file: `--quality=low|medium|high`, else `sandbox_quality` (high). The window settings and the vegetation switch
##   stay as the run started; without a preset FloraField plants nothing, so a capture would show a bare ground.

## The shared preference (data/ui/graphics_prefs.tres).
@export var prefs: GraphicsPrefs
## The world's look rig; empty in the boot (window settings only).
@export var rig: LookRig
## The `id` of the preset a sandboxed run with a window gets when it passes no `--quality=`.
@export var sandbox_quality: StringName = &"high"


func _ready() -> void:
	if _sandbox_preset_only():
		apply_sandbox_preset()
		return
	if _inert():
		return
	# A scene the flow swaps in (change_scene) enters the tree BEFORE it becomes the current scene, so `_owns_scene()` is
	# false here and the player's preset would never reach the rig (no vegetation until the options change): wait for it.
	if not _owns_scene():
		await get_tree().process_frame
		if not is_inside_tree():
			return
	if prefs == null:
		push_warning("GraphicsApplier: falta prefs; no se aplica nada.")
		return
	prefs.changed.connect(apply)
	apply()


## Applies everything the preference holds; cheap when nothing changed.
func apply() -> void:
	if _inert() or prefs == null:
		return
	if not _owns_scene():
		return
	_apply_window()
	var line := "gráficos: %s · vsync %s · pantalla completa %s · tope %s · vegetación %s" % [
		prefs.quality_id(), _yes(prefs.vsync()), _yes(prefs.fullscreen()),
		str(prefs.max_fps()) if prefs.max_fps() > 0 else "no", _yes(prefs.vegetation_enabled()),
	]
	if _has_rig():
		rig.set_vegetation_enabled(prefs.vegetation_enabled())
	var preset := prefs.quality()
	if _has_rig() and preset and rig.quality_preset != preset:
		var started := Time.get_ticks_usec()
		rig.apply_quality(preset)
		line += " · preset aplicado en %d ms" % roundi((Time.get_ticks_usec() - started) / 1000.0)
	print(line)


## Sandboxed run with a window: the deterministic preset on the rig, nothing read from or written to the player's file.
## Waits a frame: the map binds `rig` and the flow makes this world the current scene while it enters the tree.
func apply_sandbox_preset() -> void:
	await get_tree().process_frame
	if not _sandbox_preset_only() or prefs == null or not _owns_scene() or not _has_rig():
		return
	var preset := prefs.forced_quality()
	if preset == null:
		preset = prefs.preset_for(sandbox_quality)
	if preset != null and rig.quality_preset != preset:
		rig.apply_quality(preset)


func _sandbox_preset_only() -> bool:
	if Engine.is_editor_hint() or DisplayServer.get_name() == "headless" or MpBoot.is_dedicated_process():
		return false
	return UserSettings.sandboxed()


func _apply_window() -> void:
	var window := get_window()
	_snapshot_launch(window)
	if not _launch_overrides.get("mode", false):
		var full := window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
		if prefs.fullscreen() and not full:
			window.mode = Window.MODE_FULLSCREEN
		elif not prefs.fullscreen() and full:
			window.mode = Window.MODE_WINDOWED
	if not _launch_overrides.get("vsync", false):
		var vsync := DisplayServer.VSYNC_ENABLED if prefs.vsync() else DisplayServer.VSYNC_DISABLED
		if DisplayServer.window_get_vsync_mode() != vsync:
			DisplayServer.window_set_vsync_mode(vsync)
	if not _launch_overrides.get("max_fps", false):
		Engine.max_fps = prefs.max_fps()


## The scene that owns this node is the running one: the boot, or the world the flow (or F6 on it) is running.
func _owns_scene() -> bool:
	return owner != null and is_inside_tree() and owner == get_tree().current_scene


func _has_rig() -> bool:
	return rig != null and is_instance_valid(rig) and rig.is_inside_tree()


func _inert() -> bool:
	if Engine.is_editor_hint() or DisplayServer.get_name() == "headless":
		return true
	if MpBoot.is_dedicated_process():
		return true
	return UserSettings.sandboxed()


## What the engine's own command line set for this run. Godot consumes its flags (--max-fps, --disable-vsync,
## -f/-w) before OS.get_cmdline_args(), so they are detected by comparing the state at launch with the project
## settings, once per process and before this node ever touches the window (the boot's applier runs first).
static var _launch_overrides := {}


static func _snapshot_launch(window: Window) -> void:
	if not _launch_overrides.is_empty():
		return
	var project_mode := int(ProjectSettings.get_setting("display/window/size/mode", Window.MODE_WINDOWED))
	var project_vsync := int(ProjectSettings.get_setting("display/window/vsync/vsync_mode", DisplayServer.VSYNC_ENABLED))
	var project_fps := int(ProjectSettings.get_setting("application/run/max_fps", 0))
	_launch_overrides = {
		"mode": int(window.mode) != project_mode,
		"vsync": int(DisplayServer.window_get_vsync_mode()) != project_vsync,
		"max_fps": Engine.max_fps != project_fps,
	}


static func _yes(on: bool) -> String:
	return "sí" if on else "no"


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var socket := GraphicsPrefs.socket_warning(prefs)
	if not socket.is_empty():
		warnings.append(socket)
	return warnings
