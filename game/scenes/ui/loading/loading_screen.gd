class_name LoadingScreen
extends CanvasLayer

## The black screen while a match loads: a title, what it is doing (reading the world, preparing the graphics) and a thin bar.
## It covers the world from the first file until the world says it is ready, then fades out. While it shows, the game gets no
## input (Esc does not open the pause menu behind it). It runs with the tree paused (the start gate holds the match meanwhile).
## Not: what loads or when the match starts (the flow's MpWorldLoader, the gate): it only shows what the flow tells it.

## The line under the title while the files are read.
@export var files_key := &"UI_LOADING_WORLD"
## The line under the title while the world gets ready (the shaders warm up).
@export var world_key := &"UI_LOADING_SHADERS"
## Seconds of the fade out once the world is ready.
@export_range(0.0, 2.0, 0.05) var fade_s := 0.3

var _tween: Tween
var _blocking := false


func _ready() -> void:
	_hide_now()


## The flow's world_load_progressed: FILES/WORLD show it and move the bar, READY fades it out, IDLE (the load was dropped) hides it.
func show_progress(ratio: float, phase: MpWorldLoader.Phase) -> void:
	match phase:
		MpWorldLoader.Phase.FILES, MpWorldLoader.Phase.WORLD:
			_show()
			%Phase.text = tr(files_key if phase == MpWorldLoader.Phase.FILES else world_key)
			## Never back: a new phase starts where the last one ended.
			%Bar.value = maxf(%Bar.value, ratio)
		MpWorldLoader.Phase.READY:
			%Bar.value = 1.0
			_fade_out()
		_:
			_hide_now()


func _show() -> void:
	_stop_fade()
	if not visible:
		%Bar.value = 0.0
	%Backdrop.modulate.a = 1.0
	visible = true
	_block_input(true)


func _fade_out() -> void:
	if not visible:
		return
	_stop_fade()
	_block_input(false)
	_tween = create_tween()
	_tween.tween_property(%Backdrop, "modulate:a", 0.0, fade_s)
	_tween.tween_callback(_hide_now)


func _hide_now() -> void:
	_stop_fade()
	visible = false
	_block_input(false)


func _stop_fade() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


## While it shows, the window passes no input to the game (pause menu, camera, orders).
func _block_input(on: bool) -> void:
	if on == _blocking:
		return
	_blocking = on
	get_viewport().gui_disable_input = on
