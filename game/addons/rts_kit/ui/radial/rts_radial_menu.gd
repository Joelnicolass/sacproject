@tool
class_name RtsRadialMenu
extends RtsOrderMenu

## The kit's radial menu, one RtsOrderMenu among any a game may write: rings of icons around the point
## where it opened (RtsRadialLayout: any number of rings, filled by hand or from the catalogs). It
## says which entry the pointer is on (by angle and distance) and emits `entry_chosen` or `cancelled`;
## the dead zone cancels. It knows no order and no network: RtsOrderButton opens it, feeds the
## pointer and runs what it chose. Optional: a rig without it is a plain right click.
## Pieces: RtsRadialDecor draws the rings, sector, pointer and center; RtsRadialRings holds the icons;
## RtsRadialAnimator opens and closes it.

## The menu opened. A sound may listen.
signal opened
## The pointer moved onto `entry` (null: onto nothing).
signal hovered_changed(entry: RtsMenuEntry)

@export var layout: RtsRadialLayout:
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
@export var decor: RtsRadialDecor
@export var rings: RtsRadialRings
@export var animator: RtsRadialAnimator

## The entry under the pointer, or null.
var hovered: RtsMenuEntry

var _origin := Vector2.ZERO
var _open := false
var _last_hover: RtsMenuEntry
var _built := ""


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if layout == null or decor == null or rings == null:
		warnings.append("Assign layout, decor and rings.")
	return warnings


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		_refresh_preview()
		return
	visible = false
	if animator:
		animator.closed.connect(
			func() -> void:
				if not _open:
					visible = false
		)


func is_open() -> bool:
	return _open


## Where the menu opened (screen pixels).
func origin() -> Vector2:
	return _origin


func open_at(screen: Vector2, context: StringName) -> void:
	if layout == null:
		return
	_rebuild()
	_origin = screen
	position = screen - size * 0.5
	if decor and decor.center_rect:
		decor.center_rect.texture = layout.context_icons.get(context, layout.center_icon)
	_open = true
	hovered = null
	_last_hover = null
	_show_hover(null, Vector2i(0, 0), Vector2.ZERO)
	if decor:
		decor.set_active(true)
	visible = true
	if animator:
		animator.open()
	opened.emit()


func point_at(screen: Vector2) -> RtsMenuEntry:
	if layout == null:
		return null
	var offset := screen - _origin
	var spot := layout.locate(offset)
	hovered = layout.entry_of(spot)
	_show_hover(hovered, spot, offset)
	return hovered


## The entry the pointer is on, without moving anything. Same math as `point_at`.
func entry_at(screen: Vector2) -> RtsMenuEntry:
	return layout.entry_at(screen - _origin) if layout else null


func confirm() -> RtsMenuEntry:
	var chosen := hovered
	_close()
	if chosen != null:
		entry_chosen.emit(chosen)
		return chosen
	cancelled.emit()
	return null


func cancel() -> void:
	if not _open:
		return
	_close()
	cancelled.emit()


func _close() -> void:
	_open = false
	hovered = null
	_show_hover(null, Vector2i(-1, -1), Vector2.ZERO)
	if decor:
		decor.set_active(false)
	if animator:
		animator.close()
	else:
		visible = false
	if Engine.is_editor_hint():
		visible = false


## The icons grow / dim, the sector fades in, and `hovered_changed` fires when the entry changed.
func _show_hover(entry: RtsMenuEntry, spot: Vector2i, offset: Vector2) -> void:
	var changed := entry != _last_hover
	if rings:
		rings.show_hover(entry, _open)
	if decor:
		decor.set_hover(spot, offset, entry, changed)
	if changed:
		_last_hover = entry
		hovered_changed.emit(entry)


func _rebuild() -> void:
	if layout == null:
		return
	var signature := layout.signature()
	if signature == _built and rings and rings.get_child_count() > 0:
		return
	_built = signature
	size = Vector2.ONE * layout.outer_radius() * 2.0
	pivot_offset = size * 0.5
	scale = Vector2.ONE
	if rings:
		rings.build(layout)
	if decor:
		decor.fit(layout)


func _refresh_preview() -> void:
	if preview_open and layout != null:
		open_at(Vector2.ZERO, &"")
		position = Vector2.ZERO
		_origin = size * 0.5
	else:
		_open = false
		visible = false
