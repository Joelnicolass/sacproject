extends Node3D

## RFC-053 053e (F374): the info box of the original over each kind of body. With a window: move the mouse over them (the box
## shows after 0,5 s); click the house with the inspector... (the scene has no MatchCommand: `inspect_house` in the remote tree).
## Headless (or `-- --check`): the camera's `debug_pointer` aims at each body in turn and the run checks
## - hidden at 0,4 s and shown at 0,6 s after the pointer lands on it; hidden again within 0,1 s when it leaves;
## - the exact title, the bar (none on the gravestone `grv3`) and its fraction (± 0,01), also after the house loses health;
## - the house inspected and nothing hovered: the box pinned; the inspection cleared: hidden;
## - `TargetInfoPanel.place` inside 1280×720 and 1920×1080 with the HUD at 100 % and 150 %, and the live box inside the viewport.
## Prints `TARGET_INFO <check>: PASS|FAIL` and `TARGET_INFO PASS|FAIL`; quits 0 / 1. Watchdog: `timeout_s` real seconds.

## Real seconds (not game time: --fixed-fps would stretch a game-time timer).
@export var timeout_s := 20.0
@export var camera: Camera3D
@export var probe: TargetProbe
@export var panel: TargetInfoPanel
@export var inspector: StructureInspector
@export var grave: Node3D
@export var house: Node3D
@export var manalith: Node3D
@export var free_fount: Node3D
@export var trogg: Node3D
@export var wizard: Node3D
@export var blue_soul: Node3D
@export var red_soul: Node3D

var _done := false
var _failed := false
var _deadline := 0


func _init() -> void:
	_deadline = Time.get_ticks_msec() + int(timeout_s * 1000.0)


func _ready() -> void:
	_deadline = Time.get_ticks_msec() + int(timeout_s * 1000.0)
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or args.has("--check"):
		_run.call_deferred()


func _process(_delta: float) -> void:
	if not _done and _deadline > 0 and Time.get_ticks_msec() > _deadline and (DisplayServer.get_name() == "headless" \
			or OS.get_cmdline_user_args().has("--check")):
		_done = true
		print("TARGET_INFO FAIL timeout")
		get_tree().quit(1)


## With a window: inspect the house as a click would (the scene has no MatchCommand).
func inspect_house() -> void:
	inspector.inspect(house)


func _run() -> void:
	await _wait(0.3)
	var house_health := house.get_node("Health") as Health
	var cases := [
		[grave, UiText.t(&"TARGET_INFO_BUILDING"), false],
		[house, UiText.t(&"TARGET_INFO_BUILDING"), true],
		[manalith, UiText.t(&"TARGET_INFO_MANALITH"), true],
		[free_fount, UiText.t(&"TARGET_INFO_MANAFOUNT"), false],
		[trogg, UiText.t(&"TARGET_INFO_OF") % ["Trogg", "Eldred"], true],
		[wizard, "Eldred", true],
		[blue_soul, UiText.t(&"TARGET_INFO_SOUL"), false],
		[red_soul, UiText.t(&"TARGET_INFO_SOUL_PAGAN"), false],
	]
	for case in cases:
		await _hover_case(case[0], case[1], case[2])
	# The bar follows Health.changed: the house at 75 %.
	_aim(house)
	await _wait(0.6)
	house_health.current = house_health.maximum * 0.75
	await get_tree().process_frame
	_check("house bar follows its health", panel.visible and absf(panel.shown_fraction - 0.75) <= 0.01 \
		and absf((panel.get_node("%Bar") as HealthStrip).fraction - 0.75) <= 0.01)
	# Off everything: hidden within 0,1 s.
	_aim_screen(Vector2(4.0, 4.0))
	await _wait(0.1)
	_check("sky hides the box within 0.1 s", not panel.visible)
	# Pinned: the house inspected, nothing hovered.
	inspector.inspect(house)
	await _wait(0.1)
	_check("inspected house pinned", panel.visible and panel.pinned and panel.shown_title == UiText.t(&"TARGET_INFO_BUILDING"))
	_check("pinned box inside the viewport", _inside(panel.screen_rect(), get_viewport().get_visible_rect().size))
	inspector.clear()
	await _wait(0.05)
	_check("inspection cleared hides it", not panel.visible)
	_check_placement()
	await _check_live_1080()
	_done = true
	print("TARGET_INFO ", "FAIL" if _failed else "PASS")
	get_tree().quit(1 if _failed else 0)


func _hover_case(body: Node3D, title: String, bar: bool) -> void:
	var label := str(body.name)
	_aim(body)
	await _wait(0.1)
	_check("%s hovered (got %s, aim %s)" % [label, probe.hovered.name if probe.hovered else "nada", _aim_point(body)], probe.hovered == body)
	await _wait(0.3)
	_check("%s hidden at 0.4 s" % label, not panel.visible)
	await _wait(0.2)
	_check("%s shown at 0.6 s" % label, panel.visible)
	_check("%s title «%s» (got «%s»)" % [label, title, panel.shown_title], panel.shown_title == title)
	_check("%s bar %s" % [label, "yes" if bar else "no"], panel.shown_has_bar == bar)
	if bar:
		var health := body.get_node("Health") as Health
		_check("%s fraction" % label, absf(panel.shown_fraction - health.current / health.maximum) <= 0.01)
	_check("%s box inside the viewport" % label, _inside(panel.screen_rect(), get_viewport().get_visible_rect().size))


## Every pointer on a grid of the screen, at both sizes and both HUD scales: the box stays inside.
func _check_placement() -> void:
	var scale := (panel.hud_scale.duplicate() as HudScale)
	scale.max_scale = 2.0
	var ok := true
	for view in [Vector2(1280.0, 720.0), Vector2(1920.0, 1080.0)]:
		for hud in [1.0, 1.5]:
			scale.set_scale(hud, false)
			var factor := scale.factor(view.y)
			var box: Vector2 = panel.box_units * factor
			for x in 11:
				for y in 11:
					var pointer := Vector2(view.x * x / 10.0, view.y * y / 10.0)
					var at := TargetInfoPanel.place(pointer, box, view, panel.cursor_gap_units * factor)
					if not _inside(Rect2(at, box), view):
						ok = false
						print("TARGET_INFO_NOTE outside: view %s hud %s pointer %s at %s" % [view, hud, pointer, at])
	_check("place() inside 1280x720 and 1920x1080 at HUD 100 % and 150 %", ok)


## The live box at 1920×1080, the pointer near the bottom-right corner: it mirrors and stays inside.
func _check_live_1080() -> void:
	get_tree().root.size = Vector2i(1920, 1080)
	await _wait(0.05)
	var view := get_viewport().get_visible_rect().size
	print("TARGET_INFO_NOTE viewport %s" % view)
	_aim(trogg)
	await _wait(0.6)
	var at := camera.unproject_position(_aim_point(trogg))
	_check("live box shown at %s" % view, panel.visible)
	_check("live box inside %s" % view, _inside(panel.screen_rect(), view))
	_check("live box beside the pointer", panel.screen_rect().grow(panel.cursor_gap_units * 4.0).has_point(at))


static func _inside(rect: Rect2, view: Vector2) -> bool:
	return rect.position.x >= -0.01 and rect.position.y >= -0.01 and rect.end.x <= view.x + 0.01 and rect.end.y <= view.y + 0.01


func _aim(body: Node3D) -> void:
	_aim_screen(camera.unproject_position(_aim_point(body)))


func _aim_screen(at: Vector2) -> void:
	camera.set("debug_pointer", at)


## The middle of the body's first collision shape (a soul: its Target area).
func _aim_point(body: Node3D) -> Vector3:
	for shape in body.find_children("*", "CollisionShape3D", true, false):
		return (shape as CollisionShape3D).global_position
	return body.global_position + Vector3.UP


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _check(label: String, ok: bool) -> void:
	print("TARGET_INFO %s: %s" % [label, "PASS" if ok else "FAIL"])
	if not ok:
		_failed = true
