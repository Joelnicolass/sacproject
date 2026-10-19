@tool
class_name TargetInfoPanel
extends Control

## RFC-053 053e (F374): the original's info box (renderer.d:66 and 5036-5230, described). Local presentation: no RPC, no sim.
## - Hover: `delay_s` after TargetProbe names a new body, the box shows beside the pointer what TargetInfo says about it, and
##   follows the pointer while it stays on that body. It mirrors to the left of the pointer near the right edge and is clamped
##   inside the viewport. Another body, or none, hides it at once (on the probe's next sample, 30 a second).
## - Pinned: with nothing hovered and a building inspected by click (StructureInspector), the box shows that building, fixed at
##   `pinned_margin_units` from the bottom-left corner, until the inspection ends.
## - The bar and the text follow Health.changed of the body shown, not every frame.
## - Size: `box_units` HUD units × HudScale (the HUD's one knob). The layout of the children is proportional in the .tscn.
## - FeelPrefs.hover_info off turns the hover box off; the pinned one still shows (it was clicked).

## Read-only views for flows and checks (AgentKit reads properties).
var shown_title: String:
	get:
		return (%Title as Label).text if visible else ""
var shown_fraction: float:
	get:
		return _info.fraction if visible and _info != null else NAN
var shown_has_bar: bool:
	get:
		return visible and (%Bar as Control).visible
var pinned: bool:
	get:
		return visible and _pinned

@export var probe: TargetProbe
## Optional: the clicked building stays in the box (empty: no pinned box).
@export var inspector: StructureInspector
@export var hud_scale: HudScale
@export var prefs: FeelPrefs
## Seconds the pointer stays on a body before the box shows (renderer.d:66).
@export var delay_s := 0.5
@export var box_units := Vector2(220.0, 70.0)
## HUD units between the pointer and the box.
@export var cursor_gap_units := 16.0
## Where the pinned box sits: HUD units from the left and from the bottom edge (above the spell book).
@export var pinned_margin_units := Vector2(8.0, 120.0)
## Title font size in HUD units.
@export var title_font_units := 13.0

## The body hovered and waiting for the delay, the one shown, and how long it has waited.
var _pending: Node
var _shown: Node
var _wait := 0.0
var _info: TargetInfo
var _pinned := false
## The title's left anchor of the .tscn (beside the icon).
var _title_left := 0.0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if probe == null:
		warnings.append("Asigná `probe` (el TargetProbe que dice qué hay bajo el puntero).")
	var scale_warning := HudScale.socket_warning(hud_scale)
	if not scale_warning.is_empty():
		warnings.append(scale_warning)
	var prefs_warning := FeelPrefs.socket_warning(prefs)
	if not prefs_warning.is_empty():
		warnings.append(prefs_warning)
	return warnings


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	_title_left = (%Title as Label).anchor_left
	if Engine.is_editor_hint():
		return
	if probe:
		probe.hovered_changed.connect(_on_hovered_changed)
	if inspector:
		inspector.inspected_changed.connect(_on_inspected_changed)
	if hud_scale:
		hud_scale.changed.connect(_resize)
	get_viewport().size_changed.connect(_resize)
	_resize()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _shown != null and not is_instance_valid(_shown):
		_hide()
	if _pending != null and not is_instance_valid(_pending):
		_pending = null
	if _pending != null and _shown != _pending:
		_wait += delta
		if _wait >= delay_s and _hover_on():
			_show(_pending, false)
	elif _pending == null and _shown == null:
		_try_pin()
	if visible and not _pinned:
		position = place(probe.pointer if probe else Vector2.ZERO, size, get_viewport_rect().size, cursor_gap_units * _factor())


## Top-left corner of a box of `box` pixels beside `pointer` inside a `view`-sized screen: `gap` to the right and below the
## pointer; to the left when it would leave the right edge, above when it would leave the bottom; then clamped inside.
static func place(pointer: Vector2, box: Vector2, view: Vector2, gap: float) -> Vector2:
	var at := pointer + Vector2(gap, gap)
	if at.x + box.x > view.x:
		at.x = pointer.x - gap - box.x
	if at.y + box.y > view.y:
		at.y = pointer.y - gap - box.y
	at.x = clampf(at.x, 0.0, maxf(view.x - box.x, 0.0))
	at.y = clampf(at.y, 0.0, maxf(view.y - box.y, 0.0))
	return at


## The panel's rectangle on screen (checks read it).
func screen_rect() -> Rect2:
	return Rect2(position, size)


func _on_hovered_changed(node: Node) -> void:
	_wait = 0.0
	_pending = node if TargetInfo.describe(node, MpKit.local_slot()) != null else null
	if _shown != null and _shown != _pending:
		_hide()


func _on_inspected_changed(_body: Node3D) -> void:
	if _pinned:
		_hide()


func _try_pin() -> void:
	if inspector == null or inspector.inspected == null or not is_instance_valid(inspector.inspected):
		return
	_show(inspector.inspected, true)


func _show(node: Node, pin: bool) -> void:
	var info := TargetInfo.describe(node, MpKit.local_slot())
	if info == null:
		_pending = null
		return
	_unbind()
	_shown = node
	_pinned = pin
	_info = info
	if info.health:
		info.health.changed.connect(_on_health_changed)
	_fill(info)
	if pin:
		var view := get_viewport_rect().size
		var margin := pinned_margin_units * _factor()
		position = Vector2(margin.x, view.y - margin.y - size.y)
	visible = true


func _hide() -> void:
	_unbind()
	_shown = null
	_info = null
	_pinned = false
	visible = false


func _unbind() -> void:
	if _info != null and _info.health != null and is_instance_valid(_info.health) \
			and _info.health.changed.is_connected(_on_health_changed):
		_info.health.changed.disconnect(_on_health_changed)


func _on_health_changed(_current: float, _maximum: float) -> void:
	if _shown == null or not is_instance_valid(_shown):
		_hide()
		return
	var info := TargetInfo.describe(_shown, MpKit.local_slot())
	if info == null:
		_hide()
		return
	_info.fraction = info.fraction
	_info.title = info.title
	_fill(_info)


func _fill(info: TargetInfo) -> void:
	(%Title as Label).text = info.title
	var icon := %Icon as TextureRect
	icon.texture = info.icon
	icon.visible = info.icon != null
	# Without an icon the title starts where the icon would (the .tscn's proportional layout).
	(%Title as Label).anchor_left = _title_left if icon.visible else icon.anchor_left
	var bar := %Bar as HealthStrip
	bar.visible = info.has_bar()
	if info.has_bar():
		bar.fraction = info.fraction


func _hover_on() -> bool:
	return prefs == null or prefs.hover_info()


func _factor() -> float:
	var height := get_viewport_rect().size.y
	return hud_scale.factor(height) if hud_scale else height / HudScale.SACENGINE_HEIGHT


func _resize() -> void:
	var factor := _factor()
	size = box_units * factor
	(%Title as Label).add_theme_font_size_override(&"font_size", maxi(roundi(title_font_units * factor), 8))
