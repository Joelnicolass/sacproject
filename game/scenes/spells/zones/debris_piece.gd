class_name DebrisPiece
extends Node3D

## A rock thrown by a blast: it flies on a parabola, spins, bounces on the land keeping little of its speed, leaves a trail of fire and goes
## when it stops bouncing or after `life_s`. Presentation only: every peer draws its own and a headless process draws none. It hurts nobody.
## Ref: sacengine updateDebris (state.d:15054-15083).

@export var rock: MeshInstance3D
## Optional. The mark it leaves on the ground where it stops (a crack).
@export var landing_mark: ScarMark
## What it puffs behind it, every `trail_every_s`.
@export var trail: ParticleType
@export_range(0.0, 100.0, 0.5, "suffix:m/s²") var gravity := 30.0
## What is left of the vertical speed after a bounce.
@export_range(0.0, 1.0, 0.05) var bounce := 0.2
@export_range(0.1, 10.0, 0.1, "suffix:s") var life_s := 3.0
@export_range(0.005, 1.0, 0.005, "suffix:s") var trail_every_s := 0.033

var velocity := Vector3.ZERO
var _axis := Vector3.UP
var _turn := 0.0
var _age := 0.0
var _puff := 0.0
var _land: GroundSurface


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		queue_free()
		return
	_land = GroundSurface.of(self)


## Throws it: velocity in m/s, spinning `turn` rad/s around `axis`.
func launch(speed: Vector3, axis: Vector3, turn: float) -> void:
	velocity = speed
	_axis = axis
	_turn = turn


func _process(delta: float) -> void:
	_age += delta
	if _age >= life_s:
		queue_free()
		return
	global_position += velocity * delta
	velocity.y -= gravity * delta
	rotate(_axis, _turn * delta)
	var ground := _land.height_at(global_position.x, global_position.z) if _land != null else NAN
	if not is_nan(ground) and global_position.y < ground:
		global_position.y = ground
		velocity.y *= -bounce
		if velocity.y < 1.0:
			if landing_mark != null:
				landing_mark.mark()
			queue_free()
			return
	_puff += delta
	if trail != null and _puff >= trail_every_s:
		_puff = fmod(_puff, trail_every_s)
		FxBus.play_puff(trail.bus_name(), global_position)
