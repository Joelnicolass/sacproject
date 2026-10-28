@tool
class_name RadialMenu
extends Control

## A radial menu (the X menu): two rings of icons around the point where it opened. It shows the
## entries of its `layout`, says which one the pointer is on (by angle and distance,
## `RadialLayout.locate`) and emits `entry_chosen` or `cancelled`. It knows no order and no network.
## Whoever opens it feeds the pointer (`point_at`) and ends it (`confirm` on release, `cancel`).
## Everything is laid out in canvas pixels of the 1280×720 base; Godot's stretch scales it.
## Pieces: `RadialDecor` draws the rings, sector, pointer and center; `RadialRings` holds the icons;
## `RadialAnimator` opens and closes it. Run alone (F6) the `Standalone` child drives it with the
## mouse.

## The menu opened (open_at). MenuSounds listens.
signal opened
## The pointer moved onto `entry` (null: onto nothing).
signal hovered_changed(entry: RadialEntry)
## The pointer was released on `entry` and the menu closed.
signal entry_chosen(entry: RadialEntry)
## The menu closed on nothing (outside the rings, or `cancel`).
signal cancelled

@export var layout: RadialLayout:
	set(value):
		layout = value
		if is_node_ready():
			_rebuild()
## Editor only: shows the menu open in the middle of its own rectangle.
@export var preview_open := false:
	set(value):
		preview_open = value
		if is_node_ready() and Engine.is_editor_hint():
			_refresh_preview()
@export_group("Sockets")
@export var decor: RadialDecor
@export var rings: RadialRings
@export var animator: RadialAnimator

## The entry under the pointer, or null.
var hovered: RadialEntry

var _origin := Vector2.ZERO
var _open := false
var _last_hover: RadialEntry


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if layout == null or decor == null or rings == null or animator == null:
		warnings.append("Assign layout, decor, rings and animator.")
	return warnings


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		_refresh_preview()
		return
	visible = false
	animator.closed.connect(
		func() -> void:
			if not _open:
				visible = false
	)


func is_open() -> bool:
	return _open


## Opens the menu centered on the screen point `screen` (pixels). `center_icon` replaces the one of
## the layout's center.
func open_at(screen: Vector2, center_icon: Texture2D = null) -> void:
	if layout == null:
		return
	_origin = screen
	_resize_to_layout()
	position = screen - size * 0.5
	var center_rect := decor.center_rect
	center_rect.texture = (
		center_icon
		if center_icon != null
		else (layout.center.display_icon() if layout.center else null)
	)
	_open = true
	hovered = null
	_last_hover = null
	_show_hover(null, Vector2i(0, 0), Vector2.ZERO)
	decor.set_active(true)
	visible = true
	animator.open()
	opened.emit()


## The pointer is at `screen` (pixels): highlights what it is on and returns it.
func point_at(screen: Vector2) -> RadialEntry:
	if layout == null:
		return null
	var offset := screen - _origin
	var spot := layout.locate(offset)
	hovered = layout.entry_of(spot)
	_show_hover(hovered, spot, offset)
	return hovered


## The entry the pointer is on, without moving anything. Same math as `point_at`.
func entry_at(screen: Vector2) -> RadialEntry:
	return layout.entry_at(screen - _origin) if layout else null


## Ends the menu where the pointer is: `entry_chosen` with its entry, or `cancelled` over nothing.
## Returns the entry.
func confirm() -> RadialEntry:
	var chosen := hovered
	_close()
	if chosen != null:
		entry_chosen.emit(chosen)
	else:
		cancelled.emit()
	return chosen


func cancel() -> void:
	if not _open:
		return
	_close()
	cancelled.emit()


func _close() -> void:
	_open = false
	hovered = null
	_show_hover(null, Vector2i(-1, -1), Vector2.ZERO)
	decor.set_active(false)
	animator.close()
	if Engine.is_editor_hint():
		visible = false


## The icons grow / dim, the sector fades in, and `hovered_changed` fires when the entry changed.
func _show_hover(entry: RadialEntry, spot: Vector2i, offset: Vector2) -> void:
	var changed := entry != _last_hover
	rings.show_hover(entry if entry != layout.center else null, _open)
	decor.set_hover(spot, offset, entry, changed)
	if changed:
		_last_hover = entry
		hovered_changed.emit(entry)


func _resize_to_layout() -> void:
	size = Vector2.ONE * layout.outer_radius_px * 2.0
	pivot_offset = size * 0.5
	scale = Vector2.ONE
	decor.fit(layout)


func _rebuild() -> void:
	if layout == null or rings == null or decor == null:
		return
	rings.build(layout)
	_resize_to_layout()


func _refresh_preview() -> void:
	if preview_open and layout != null:
		_rebuild()
		open_at(Vector2.ZERO)
		position = Vector2.ZERO
		_origin = size * 0.5
	else:
		_open = false
		visible = false
