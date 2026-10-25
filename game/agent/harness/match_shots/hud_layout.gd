extends RefCounted

## Measures the HUD of a running match for the "hud" view of match_shots (055h-1): where each widget sits as a fraction of the canvas
## height, the size the hardware cursor was given, and whether the pointer and the world agree (a ray from five screen points hits the
## ground and projects back onto the same point). It writes <png>.json next to the capture and changes nothing in the game.
## Canvas = the window's content area after Godot's stretch (1280×720 at the base, wider with `expand`, smaller with a bigger interface size).

## How far from the corners the four corner points of the pointer check sit, in canvas pixels.
const POINT_INSET_PX := 60.0
## Widgets measured: [key, node name]. Found by name under the match (recursive).
const WIDGETS: Array = [
	["SpellBook", "SpellBook"],
	["WizardStats", "WizardStats"],
	["ManaBar", "ManaBar"],
	["HealthBar", "HealthBar"],
	["Minimap", "Minimap"],
	["RadialMenu", "RadialMenu"],
]


## Writes `json_path` (an absolute path) for the match `world`, seen through `camera` (the game's own).
static func write(world: MatchWorld, camera: Camera3D, json_path: String) -> void:
	var canvas := world.get_viewport().get_visible_rect().size
	var window := world.get_window()
	var data := {
		"window_px": [window.size.x, window.size.y],
		"canvas_px": [canvas.x, canvas.y],
		"content_scale_factor": window.content_scale_factor,
		"rects": _rects(world, canvas),
		"roster_book_gap_px": _gap(world),
		"cursor": _cursor(world, window, canvas),
		"pointer_roundtrip": _roundtrip(world, camera, canvas),
	}
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file == null:
		push_warning("hud_layout: cannot write %s" % json_path)
		return
	file.store_string(JSON.stringify(data, "  "))
	print("hud_layout: %s" % json_path)


## One entry per widget: its rectangle and its gaps to the four canvas edges, all as a fraction of the canvas height.
static func _rects(world: MatchWorld, canvas: Vector2) -> Dictionary:
	var out := {}
	for entry: Array in WIDGETS:
		var control := world.find_child(entry[1], true, false) as Control
		if control != null:
			out[entry[0]] = _entry(control.get_global_rect(), canvas, control.is_visible_in_tree())
	var roster := world.find_child("SelectionRoster", true, false) as Control
	var frame := roster.find_child("Frame", true, false) if roster != null else null
	if frame != null:
		var union := Rect2()
		var first := true
		for child in frame.get_children():
			if child is Control:
				var rect := (child as Control).get_global_rect()
				union = rect if first else union.merge(rect)
				first = false
		out["RosterFrame"] = _entry(union, canvas, roster.is_visible_in_tree())
	return out


static func _entry(rect: Rect2, canvas: Vector2, visible: bool) -> Dictionary:
	var height := maxf(canvas.y, 1.0)
	return {
		"visible": visible,
		"px": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"w": rect.size.x / height, "h": rect.size.y / height,
		"left": rect.position.x / height, "top": rect.position.y / height,
		"right": (canvas.x - rect.end.x) / height, "bottom": (canvas.y - rect.end.y) / height,
	}


## Canvas pixels from the roster's bottom edge to the book's top edge (criterion: at least 4 with interface size 1.4).
static func _gap(world: MatchWorld) -> Variant:
	var roster := world.find_child("SelectionRoster", true, false) as Control
	var book := world.find_child("SpellBook", true, false) as Control
	if roster == null or book == null:
		return null
	return book.get_global_rect().position.y - roster.get_global_rect().end.y


## The hardware cursor: side applied vs the formula round(cursor_px × window height / canvas height).
static func _cursor(world: MatchWorld, window: Window, canvas: Vector2) -> Dictionary:
	var skin := world.find_child("CursorSkin", true, false) as CursorSkin
	if skin == null:
		return {}
	var expected := roundi(skin.cursor_px * float(window.size.y) / maxf(canvas.y, 1.0))
	return {"applied_px": skin.applied_px, "expected_px": expected, "apply_count": skin.apply_count, "cursor": skin.current}


## Centre and four corner points: ground under the point (PointerRay), projected back; the error in canvas pixels. The HoverFrame check
## compares the frame drawn over the local wizard with the projection of the wizard's own box.
static func _roundtrip(world: MatchWorld, camera: Camera3D, canvas: Vector2) -> Dictionary:
	var ray := world.find_child("PointerRay", true, false) as PointerRay
	var points := {
		"center": canvas * 0.5,
		"top_left": Vector2(POINT_INSET_PX, POINT_INSET_PX),
		"top_right": Vector2(canvas.x - POINT_INSET_PX, POINT_INSET_PX),
		"bottom_left": Vector2(POINT_INSET_PX, canvas.y - POINT_INSET_PX),
		"bottom_right": canvas - Vector2(POINT_INSET_PX, POINT_INSET_PX),
	}
	var errors := {}
	for name: String in points:
		var point: Vector2 = points[name]
		var ground: Variant = ray.ground(point) if ray != null else null
		errors[name] = camera.unproject_position(ground as Vector3).distance_to(point) if ground is Vector3 else null
	var frame := world.find_child("HoverFrame", true, false) as HoverFrame
	var wizard := world.local_wizard()
	var hover_err: Variant = null
	if frame != null and frame.visible and wizard != null:
		var box := HoverFrameRules.screen_rect(camera, HoverFrameRules.world_corners(wizard))
		hover_err = frame.frame_rect.get_center().distance_to(box.get_center())
	return {"ground_px": errors, "hover_frame_px": hover_err}
