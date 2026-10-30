class_name RtsTargetProbe
extends Node

## Names what lies under the pointer, a few times a second; the cursor and the cue read it, a HUD may
## too. It decides nothing and draws nothing. Classes: `none` (the sky), `ground`, `hud` (over a
## control that is not the world view, or outside the window), `own_unit`, `ally_unit`,
## `neutral_unit`, `enemy_unit`, `other` (a body that is no unit), or a class of the game
## (`classify`). It also says which body is under the pointer (`hovered`).

signal kind_changed(kind: StringName)
## The body under the pointer changed (null: none).
signal hovered_changed(node: Node)

const NONE := &"none"
const GROUND := &"ground"
const HUD := &"hud"
const OTHER := &"other"

@export var pointer: RtsPointer
## Samples per second.
@export var hover_hz := 30.0
## The Control that takes the world's clicks. Over any other control the pointer is on the HUD.
@export var world_view: Control
## Controls whose rectangle is HUD even where their mouse filter lets the pointer through.
@export var hud_controls: Array[Control] = []
## Off: no samples (a dedicated server, a process with no player).
@export var enabled := true

## A class of the game for a body: `func(body: Node) -> StringName` (&"" = the kit's own).
var classify: Callable
## Class under the pointer at the last sample.
var kind: StringName = NONE
## Where it was sampled (screen pixels).
var at := Vector2(-1.0, -1.0)
## Body under the pointer at the last sample, or null; never a freed one.
var hovered: Node:
	get:
		if not is_instance_valid(hovered):
			hovered = null
		return hovered

var _since := 0.0
var _picked: Node


func _process(delta: float) -> void:
	if not enabled or pointer == null:
		return
	_since += delta
	if _since < 1.0 / maxf(hover_hz, 1.0):
		return
	_since = 0.0
	sample()


## Reads the pointer now.
func sample() -> void:
	if pointer == null:
		return
	at = pointer.pointer_now()
	_picked = null
	var next := classify_at(at)
	if next != kind:
		kind = next
		kind_changed.emit(kind)
	if _picked != hovered:
		hovered = _picked
		hovered_changed.emit(hovered)


## The pointer now (the forced one of a test, else the mouse).
func pointer_now() -> Vector2:
	return pointer.pointer_now() if pointer else get_viewport().get_mouse_position()


## The class of what lies under `screen`.
func classify_at(screen: Vector2) -> StringName:
	if _over_hud(screen):
		return HUD
	var body := pointer.body_under(screen)
	if body != null:
		_picked = body
		if classify.is_valid():
			var game_class: Variant = classify.call(body)
			if (game_class is StringName or game_class is String) and String(game_class) != "":
				return StringName(game_class)
		var relation := pointer.relation(body)
		return OTHER if relation == RtsPointer.OTHER else StringName(String(relation) + "_unit")
	return NONE if pointer.ground_at(screen) == null else GROUND


## Over the HUD: a control that is not the world view is under it, or it left the window. A test's
## forced pointer is a point of the world, never the HUD.
func _over_hud(screen: Vector2) -> bool:
	var camera := pointer.camera
	if camera != null and "debug_pointer" in camera and (camera.get("debug_pointer") as Vector2).x >= 0.0:
		return false
	if not get_viewport().get_visible_rect().has_point(screen):
		return true
	for control in hud_controls:
		if control != null and control.is_visible_in_tree():
			var local := control.get_global_transform().affine_inverse() * screen
			if Rect2(Vector2.ZERO, control.size).has_point(local):
				return true
	var under := get_viewport().gui_get_hovered_control()
	return under != null and world_view != null and under != world_view
