@tool
class_name WallSound
extends SoundEmitter3D

## The sound of a wall, on every peer, from its replicated age: one shot when it is raised or when it begins to sink, or a loop for as long
## as it stands. It names a key of the sound table (SoundEmitter3D) and plays it at the point of the wall closest to the listener (a wall
## is up to 110 m long, the sound does not come from its middle). It does not decide when a wall starts or ends (SpellWall). A dedicated
## server or a headless run plays nothing.
## Ref: sacengine playSoundAtRange (state.d:20002, 20244, 20466).

enum When { WHEN_RAISED, WHEN_SINKS, WHILE_STANDING }

@export var wall: SpellWall
@export var when := When.WHILE_STANDING

var _played := false


func _ready() -> void:
	play_on_ready = false
	loop = when == When.WHILE_STANDING
	active = false
	super()
	set_process(not Engine.is_editor_hint() and wall != null and AudioGate.is_open())


func _process(delta: float) -> void:
	if loop:
		super(delta)
	var ear: Vector3 = SoundBus.listener_position()
	if ear != Vector3.INF:
		var along := clampf(WallRules.along(ear, wall.center, wall.direction), wall.left, wall.right)
		global_position = wall.point_at(along)
	match when:
		When.WHILE_STANDING:
			set_active(wall.top() > 0.0 and wall.age > 0)
		When.WHEN_RAISED:
			_once(wall.age > 0)
		When.WHEN_SINKS:
			_once(wall.vanish_at >= 0)


func _once(now: bool) -> void:
	if now and not _played:
		_played = true
		play_once()
