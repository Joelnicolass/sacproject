@tool
class_name WardSound
extends SoundEmitter3D

## The sound of a ward, on every peer, from its replicated `shown` and the cast: one shot when the cast begins, when the ward starts or
## when it ends, or a loop from the start of the cast until the ward ends. It names a key of the sound table (SoundEmitter3D) and plays
## it at the body; it does not decide when a ward starts (Ward). A dedicated server or a headless run plays nothing.

enum When { WHEN_STARTS, WHEN_ENDS, WHILE_ON, WHEN_CAST_STARTS }

@export var ward: Ward
@export var when := When.WHEN_STARTS


func _ready() -> void:
	play_on_ready = false
	active = when != When.WHILE_ON
	loop = when == When.WHILE_ON
	super()
	if Engine.is_editor_hint() or ward == null:
		return
	ward.shown_changed.connect(_on_ward)
	ward.casting_changed.connect(_on_casting)
	_sync_loop()


func _on_ward(on: bool) -> void:
	match when:
		When.WHILE_ON:
			_sync_loop()
		When.WHEN_STARTS:
			if on:
				play_once()
		When.WHEN_ENDS:
			if not on:
				play_once()


func _on_casting(on: bool) -> void:
	if when == When.WHILE_ON:
		_sync_loop()
	elif when == When.WHEN_CAST_STARTS and on:
		play_once()


## The loop runs from the first moment of the cast to the end of the ward.
func _sync_loop() -> void:
	if when == When.WHILE_ON:
		set_active(ward.casting or ward.shown)
