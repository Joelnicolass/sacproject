@tool
class_name RtsRadialAnimator
extends AnimationPlayer

## Opens and closes the radial menu (its parent) with the `open` clip (scale + fade in) and the `close`
## clip (fade out): their length and the starting scale are keys in the animation, not code. In the
## editor it snaps.

## The `close` clip ended: the menu can hide.
signal closed


func _ready() -> void:
	if not Engine.is_editor_hint():
		animation_finished.connect(_on_finished)


func open() -> void:
	_snap_or_play(&"open")


func close() -> void:
	_snap_or_play(&"close")


func _snap_or_play(clip: StringName) -> void:
	if not Engine.is_editor_hint() and has_animation(clip):
		play(clip)
		return
	var menu := get_node_or_null(root_node) as Control
	if menu:
		menu.modulate.a = 1.0 if clip == &"open" else 0.0
		menu.scale = Vector2.ONE
	if clip == &"close" and not Engine.is_editor_hint():
		closed.emit()


func _on_finished(clip: StringName) -> void:
	if clip == &"close":
		closed.emit()
