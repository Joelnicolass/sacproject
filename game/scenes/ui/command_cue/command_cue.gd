@tool
class_name CommandCue
extends Control

## What replaces the words of the old battle line (RFC-025c), drawn at the pointer:
## `Aim` = the icon of the armed spell, structure, order or ability, 4/32 below the cursor like
## sacengine renderCursor (renderer.d:4113-4165); `Invalid` = the `ncst` icon, flashed when something
## is refused (CommandLog.said with a refusal cue) and held while the pointer is over a target the
## armed icon cannot take (an order over the sky, a structure over the wrong body);
## `Mirror` = a copy of the hardware cursor, off by default: a window capture does not include the
## system cursor, so a flow turns it on to see it.
## Without the local cache the images are null and a plain circle / cross is drawn instead.
## Full screen, ignores the mouse.

@export var command_log: CommandLog
@export var cues: CueSet
@export var probe: TargetProbe
@export var skin: CursorSkin
## Seconds the `ncst` icon stays after a refusal.
@export var flash_s := 0.6
## Show the hardware cursor's image in the viewport (captures and flows only).
@export var mirror_cursor := false:
	set(value):
		mirror_cursor = value
		if is_node_ready() and not Engine.is_editor_hint():
			_refresh_process()
			_place()
@export_group("Fallback")
@export var fallback_aim := Color(0.95, 0.85, 0.45, 0.9)
@export var fallback_invalid := Color(0.9, 0.15, 0.1, 0.95)
## Shared HUD size (the spell book, the roster and the cursor read the same one).
@export var hud_scale: HudScale = preload("res://data/ui/hud_scale.tres")
@export var icon_units := 32.0

## Seconds the last flash lasted, measured (a flow compares it with `flash_s`).
var last_flash_s := 0.0

var _flashing := false
var _hover_invalid := false
var _flash_from_ms := 0


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if command_log == null:
		warnings.append("Asigná `command_log` (el nodo Battle).")
	if cues == null:
		warnings.append("Asigná `cues` (data/ui/command_cues.tres).")
	var scale_warning := HudScale.socket_warning(hud_scale)
	if not scale_warning.is_empty():
		warnings.append(scale_warning)
	if HudIcons.icon("ncst") == null:
		warnings.append("Faltan assets/original/ui/cursors: corré tools/import/import_ui.py. Sin eso se dibuja un círculo de respaldo.")
	return warnings


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Aim.visible = false
	%Invalid.visible = false
	%Mirror.visible = false
	if Engine.is_editor_hint():
		# No game pointer in the editor; TargetProbe is not a tool script.
		set_process(false)
		return
	%FlashTimer.timeout.connect(_on_flash_done)
	if command_log:
		command_log.armed_changed.connect(_on_armed_changed)
		command_log.said.connect(_on_said)
	if probe:
		probe.kind_changed.connect(_on_kind_changed)
	if skin:
		skin.changed.connect(_on_cursor_changed)
	if hud_scale:
		hud_scale.changed.connect(_place)
	_refresh_process()


func _process(_delta: float) -> void:
	_place()


func _on_armed_changed(_kind: String, icon_tag: String) -> void:
	var armed := command_log != null and not command_log.armed.is_empty()
	%Aim.texture = HudIcons.armed(icon_tag)
	%Aim.visible = armed
	_check_hover()
	_update_invalid()
	_refresh_process()
	_place()


func _on_said(_text: String, cue: StringName) -> void:
	if cue != &"refused":
		return
	_flashing = true
	_flash_from_ms = Time.get_ticks_msec()
	%FlashTimer.start(flash_s)
	_refresh_process()
	_update_invalid()
	_place()


func _on_flash_done() -> void:
	_flashing = false
	last_flash_s = (Time.get_ticks_msec() - _flash_from_ms) / 1000.0
	_update_invalid()
	_refresh_process()


## Moves with the pointer only while something is drawn.
func _refresh_process() -> void:
	var armed := command_log != null and not command_log.armed.is_empty()
	set_process(armed or _flashing or mirror_cursor)


func _on_kind_changed(_kind: StringName) -> void:
	_check_hover()
	_update_invalid()


func _on_cursor_changed(_cursor_name: String, texture: Texture2D) -> void:
	%Mirror.texture = texture
	_place()


## The armed icon cannot take what lies under the pointer (an empty `accepts` takes anything).
func _check_hover() -> void:
	_hover_invalid = false
	if command_log == null or probe == null or command_log.armed.is_empty():
		return
	var accepts := command_log.armed_accepts
	if accepts.is_empty() or probe.kind == TargetProbe.HUD:
		return
	_hover_invalid = not accepts.has(String(probe.kind))


func _update_invalid() -> void:
	var show_it := _flashing or _hover_invalid
	%Invalid.texture = HudIcons.icon(cues.refused_icon) if (cues and show_it) else null
	%Invalid.visible = show_it
	queue_redraw()


func _place() -> void:
	var height := get_viewport().get_visible_rect().size.y
	var px := float(hud_scale.px(icon_units, height) if hud_scale else roundi(icon_units * height / HudScale.SACENGINE_HEIGHT))
	var at := probe.pointer_now() if probe else get_viewport().get_mouse_position()
	var icon_pos := at + Vector2(-0.5 * px, px * 4.0 / 32.0)
	for rect: TextureRect in [%Aim, %Invalid]:
		rect.size = Vector2(px, px)
		rect.position = icon_pos
	%Mirror.visible = mirror_cursor and %Mirror.texture != null
	%Mirror.size = Vector2(px, px)
	%Mirror.position = at - Vector2(0.5 * px, 0.0)
	if %Aim.visible and %Aim.texture == null or %Invalid.visible and %Invalid.texture == null:
		queue_redraw()


## Respaldo sin caché: un círculo por el icono armado y una cruz por el rechazo.
func _draw() -> void:
	if Engine.is_editor_hint():
		return
	if %Aim.visible and %Aim.texture == null:
		draw_circle(%Aim.position + %Aim.size * 0.5, %Aim.size.x * 0.4, fallback_aim)
	if %Invalid.visible and %Invalid.texture == null:
		var center: Vector2 = %Invalid.position + %Invalid.size * 0.5
		var r: float = %Invalid.size.x * 0.4
		draw_line(center + Vector2(-r, -r), center + Vector2(r, r), fallback_invalid, 3.0)
		draw_line(center + Vector2(-r, r), center + Vector2(r, -r), fallback_invalid, 3.0)
