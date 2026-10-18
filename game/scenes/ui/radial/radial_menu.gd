@tool
class_name RadialMenu
extends Control

## A radial menu (RFC-038 038c, sacengine's X menu): two rings of icons around the point where it opened. It shows the entries of its
## `layout`, says which one the pointer is on (by angle and distance, `RadialLayout.locate`) and emits `entry_chosen` or `cancelled`.
## It knows no order and no network. Whoever opens it feeds the pointer (`point_at`) and ends it (`confirm` on release, `cancel`).
## Everything is laid out in HUD units and `scale` grows it with the shared HudScale around its center.
## Feedback: it opens with a quick scale + fade, the hovered icon grows and glows (the others dim), a wedge and a line mark the
## sector the pointer is in, and the center shows the hovered name (and, for a formation, its shape in dots). The name is drawn
## with `draw_string`, not a Label: the HUD text audit (RFC-025c) counts Controls with text.
## Run alone (F6) it opens in the middle of the window, follows the mouse and prints the entry chosen by a click.

## The pointer moved onto `entry` (null: onto nothing).
signal hovered_changed(entry: RadialEntry)
## The pointer was released on `entry` and the menu closed.
signal entry_chosen(entry: RadialEntry)
## The menu closed on nothing (outside the rings, or `cancel`).
signal cancelled

const SLOT_SCENE := preload("res://scenes/ui/radial/radial_slot.tscn")

@export var layout: RadialLayout:
	set(value):
		layout = value
		if is_node_ready():
			_rebuild()
@export var hud_scale: HudScale = preload("res://data/ui/hud_scale.tres")
## Editor only: shows the menu open in the middle of its own rectangle.
@export var preview_open := false:
	set(value):
		preview_open = value
		if is_node_ready() and Engine.is_editor_hint():
			_refresh_preview()
@export_group("Animation")
@export var open_s := 0.12
@export var close_s := 0.08
## Size the menu opens from (1 = no growth).
@export_range(0.3, 1.0) var open_scale := 0.7
@export var hover_s := 0.12
@export_group("Look")
@export var backdrop_color := Color(0.03, 0.03, 0.06, 0.5)
@export var ring_tint := Color(0.16, 0.12, 0.05, 0.38)
@export var center_color := Color(0.02, 0.02, 0.04, 0.8)
@export var line_color := Color(0.85, 0.7, 0.3, 0.7)
@export var wedge_color := Color(1.0, 0.82, 0.3, 0.3)
@export var pointer_color := Color(1.0, 0.88, 0.45, 0.85)
@export var text_color := Color(1.0, 0.95, 0.8, 1.0)
@export var text_outline := Color(0, 0, 0, 1)
@export_range(6, 16) var font_size := 9
@export var dot_color := Color(1.0, 0.85, 0.4, 1.0)
@export var dot_radius := 1.9
## Side of the box the formation dots are fitted in (HUD units).
@export var preview_px := 26.0
@export_group("Sockets")
@export var center_rect: TextureRect
@export var rings: Control

## The entry under the pointer, or null.
var hovered: RadialEntry

var _slots: Array[RadialSlot] = []
var _origin := Vector2.ZERO
var _factor := 1.0
var _standalone := false
var _open := false
var _offset := Vector2.ZERO
var _spot := Vector2i(-1, -1)
var _hover_alpha := 0.0
var _tween: Tween
var _hover_tween: Tween
var _last_hover: RadialEntry


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if layout == null or center_rect == null or rings == null:
		warnings.append("Asigná layout, center_rect y rings.")
	var scale_warning := HudScale.socket_warning(hud_scale)
	if not scale_warning.is_empty():
		warnings.append(scale_warning)
	return warnings


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		_refresh_preview()
		return
	visible = false
	_standalone = get_tree().current_scene == self
	if _standalone:
		hovered_changed.connect(func(entry: RadialEntry) -> void: print("RADIAL hover ", entry.display_label() if entry else "-"))
		entry_chosen.connect(func(entry: RadialEntry) -> void: print("RADIAL chosen ", entry.id))
		cancelled.connect(func() -> void: print("RADIAL cancelled"))
		_open_in_middle.call_deferred()


func _open_in_middle() -> void:
	open_at(get_viewport().get_visible_rect().size * 0.5)


func is_open() -> bool:
	return _open


## Opens the menu centered on the screen point `screen` (pixels). `center_icon` replaces the one of the layout's center.
func open_at(screen: Vector2, center_icon: Texture2D = null) -> void:
	if layout == null:
		return
	_origin = screen
	_factor = 1.0
	if not Engine.is_editor_hint() and hud_scale != null:
		_factor = hud_scale.factor(get_viewport().get_visible_rect().size.y)
	_fit()
	position = screen - size * 0.5
	center_rect.texture = center_icon if center_icon != null else (layout.center.display_icon() if layout.center else null)
	_open = true
	hovered = null
	_last_hover = null
	_offset = Vector2.ZERO
	_spot = Vector2i(0, 0)
	_hover_alpha = 0.0
	_show_hover(null)
	visible = true
	if _tween:
		_tween.kill()
	if Engine.is_editor_hint() or open_s <= 0.0:
		modulate.a = 1.0
	else:
		modulate.a = 0.0
		scale = Vector2.ONE * _factor * open_scale
		_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "modulate:a", 1.0, open_s)
		_tween.tween_property(self, "scale", Vector2.ONE * _factor, open_s)
	queue_redraw()


## The pointer is at `screen` (pixels): highlights what it is on and returns it.
func point_at(screen: Vector2) -> RadialEntry:
	if layout == null:
		return null
	_offset = (screen - _origin) / maxf(_factor, 0.001)
	_spot = layout.locate(_offset)
	hovered = layout.entry_of(_spot)
	_show_hover(hovered)
	return hovered


## The entry the pointer is on, without moving anything. Same math as `point_at`.
func entry_at(screen: Vector2) -> RadialEntry:
	return layout.entry_at((screen - _origin) / maxf(_factor, 0.001)) if layout else null


## Ends the menu where the pointer is: `entry_chosen` with its entry, or `cancelled` over nothing. Returns the entry.
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
	_spot = Vector2i(-1, -1)
	_show_hover(null)
	if _tween:
		_tween.kill()
	if Engine.is_editor_hint() or close_s <= 0.0:
		visible = false
		return
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, close_s)
	_tween.tween_callback(func() -> void:
		if not _open:
			visible = false)


func _process(_delta: float) -> void:
	if _open:
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not _standalone or not _open:
		return
	if event is InputEventMouseMotion:
		point_at((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		point_at((event as InputEventMouseButton).position)
		confirm()
		_open_in_middle.call_deferred()


func _draw() -> void:
	if layout == null:
		return
	var middle := size * 0.5
	draw_circle(middle, layout.outer_radius_px, backdrop_color)
	draw_circle(middle, layout.inner_radius_px, ring_tint)
	draw_circle(middle, layout.dead_zone_px, center_color)
	draw_arc(middle, layout.dead_zone_px, 0.0, TAU, 48, line_color, 1.0, true)
	draw_arc(middle, layout.inner_radius_px, 0.0, TAU, 64, line_color, 1.0, true)
	draw_arc(middle, layout.outer_radius_px, 0.0, TAU, 64, line_color, 1.5, true)
	_draw_wedge(middle)
	_draw_pointer(middle)
	_draw_center(middle)


## The sector of the hovered ring entry, filled.
func _draw_wedge(middle: Vector2) -> void:
	if _spot.x < 1 or _spot.y < 0 or _hover_alpha <= 0.0:
		return
	var count := layout.inner.size() if _spot.x == 1 else layout.outer.size()
	var r0 := layout.dead_zone_px if _spot.x == 1 else layout.inner_radius_px
	var r1 := layout.inner_radius_px if _spot.x == 1 else layout.outer_radius_px
	var step := TAU / count
	var from := step * (_spot.y - 0.5) - PI * 0.5
	var points := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var a := from + step * i / steps
		points.append(middle + Vector2(cos(a), sin(a)) * r1)
	for i in steps + 1:
		var a := from + step * (steps - i) / steps
		points.append(middle + Vector2(cos(a), sin(a)) * r0)
	var color := wedge_color
	color.a *= _hover_alpha
	draw_colored_polygon(points, color)


## A line from the center toward the pointer, up to the outer ring.
func _draw_pointer(middle: Vector2) -> void:
	if _spot.x < 1:
		return
	var direction := _offset.normalized()
	var tip := middle + direction * minf(_offset.length(), layout.outer_radius_px)
	var base := middle + direction * layout.dead_zone_px
	draw_line(base, tip, pointer_color, 2.0, true)
	draw_circle(tip, 2.5, pointer_color)


## The hovered name (and the shape of a formation) in the dead zone; the context icon when nothing is hovered.
func _draw_center(middle: Vector2) -> void:
	var entry := hovered if _spot.x >= 1 else null
	center_rect.visible = true
	var dead := layout.dead_zone_px
	if entry == null:
		center_rect.size = Vector2.ONE * dead * 1.5
		center_rect.position = middle - center_rect.size * 0.5
		return
	var name_text := entry.display_label()
	var box := preview_px
	if entry.formation != null and not Engine.is_editor_hint():
		center_rect.visible = false
		_draw_dots(entry.formation, middle + Vector2(0.0, -dead * 0.32), box)
	else:
		center_rect.size = Vector2.ONE * box * 0.8
		center_rect.position = middle + Vector2(0.0, -dead * 0.32) - center_rect.size * 0.5
	var lines := _wrap(name_text)
	var font := get_theme_default_font()
	var top := middle.y + dead * 0.3
	for i in lines.size():
		var at := Vector2(middle.x - dead, top + i * (font_size + 1))
		draw_string_outline(font, at, lines[i], HORIZONTAL_ALIGNMENT_CENTER, dead * 2.0, font_size, 3, text_outline)
		draw_string(font, at, lines[i], HORIZONTAL_ALIGNMENT_CENTER, dead * 2.0, font_size, text_color)


func _wrap(text: String) -> PackedStringArray:
	if text.length() <= 9 or not text.contains(" "):
		return PackedStringArray([text])
	var cut := text.find(" ")
	return PackedStringArray([text.substr(0, cut), text.substr(cut + 1)])


## `formation`'s slots for eight bodies as dots: forward is up, the group fitted in a `box` square around `center`.
func _draw_dots(formation: FormationType, center: Vector2, box: float) -> void:
	var slots := formation.slots(8, 1.0, 0.0, 0)
	if slots.is_empty():
		return
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for slot in slots:
		var flat := Vector2(slot.x, -slot.y)
		low = low.min(flat)
		high = high.max(flat)
	var span := high - low
	var fit := box / maxf(maxf(span.x, span.y), 0.001)
	var mid := (low + high) * 0.5
	for slot in slots:
		var at := center + (Vector2(slot.x, -slot.y) - mid) * fit
		draw_circle(at, dot_radius + 0.9, text_outline)
		draw_circle(at, dot_radius, dot_color)


func _fit() -> void:
	size = Vector2.ONE * layout.outer_radius_px * 2.0
	pivot_offset = size * 0.5
	scale = Vector2.ONE * _factor
	var middle := size * 0.5
	center_rect.size = Vector2.ONE * layout.dead_zone_px * 1.5
	center_rect.position = middle - center_rect.size * 0.5


func _rebuild() -> void:
	for slot in _slots:
		slot.queue_free()
	_slots.clear()
	if layout == null or rings == null or center_rect == null:
		return
	_add_ring(layout.inner, layout.inner_mid())
	_add_ring(layout.outer, layout.outer_mid())
	_fit()
	queue_redraw()


func _add_ring(entries: Array[RadialEntry], radius: float) -> void:
	var middle := Vector2.ONE * layout.outer_radius_px
	for i in entries.size():
		var slot: RadialSlot = SLOT_SCENE.instantiate()
		rings.add_child(slot)
		slot.setup(entries[i], layout.icon_px)
		slot.hover_s = hover_s
		slot.position = middle + RadialLayout.slot_offset(entries.size(), i, radius) - slot.size * 0.5
		_slots.append(slot)


## Slots grow / dim, the wedge fades in, and `hovered_changed` fires when the entry changed.
func _show_hover(entry: RadialEntry) -> void:
	var ring_entry := entry if entry != layout.center else null
	for slot in _slots:
		slot.set_state(ring_entry != null and slot.entry == ring_entry, ring_entry != null, _open)
	if entry != _last_hover:
		_last_hover = entry
		if _hover_tween:
			_hover_tween.kill()
		_hover_alpha = 0.0
		if ring_entry != null and not Engine.is_editor_hint():
			_hover_tween = create_tween()
			_hover_tween.tween_property(self, "_hover_alpha", 1.0, hover_s)
		hovered_changed.emit(entry)


func _refresh_preview() -> void:
	if preview_open and layout != null:
		_rebuild()
		open_at(Vector2.ZERO)
		position = Vector2.ZERO
		_origin = size * 0.5
	else:
		_open = false
		visible = false
