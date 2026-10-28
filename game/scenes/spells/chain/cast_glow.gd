class_name CastGlow
extends FxScene

## The glow that rises around a wizard while he casts Rainbow: sprites born inside his box that
## climb on their own. A SpriteEmitter (its ParticleType says what and how many) that follows the
## wizard for the casting time and frees itself. A presentation that LaunchAction hands to
## FxBus.broadcast_scene (`play`) on every peer; it does nothing to the game.

## The emitter (a child with the ParticleType). Moved to the middle of the wizard's box and sized by
## it.
@export var emitter: SpriteEmitter

var _wizard: Node3D
var _ticks := 0


## FxBus.broadcast_scene: `ticks` the casting lasts and the `wizard` path.
func play(params: Dictionary) -> void:
	_ticks = maxi(1, int(params.get("ticks", 1)))
	_wizard = get_tree().root.get_node_or_null(NodePath(str(params.get("wizard", "")))) as Node3D
	if _wizard == null or emitter == null:
		queue_free()
		return
	var box := BodyNudge.box(_wizard)
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emitter.emission_box_extents = Vector3(box.size.x * 0.55, box.size.y * 0.5, box.size.z * 0.55)
	emitter.set_active(true)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_ticks -= 1
	if _wizard == null or not is_instance_valid(_wizard) or _ticks < 0:
		emitter.set_active(false)
		set_physics_process(false)
		get_tree().create_timer(2.0).timeout.connect(queue_free)
		return
	global_position = BodyNudge.center(_wizard)
