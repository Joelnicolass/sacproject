class_name IceShatter
extends FxScene

## One step of the breaking of Frozen Ground's ice, played on every peer by FxBus.broadcast_scene: a
## burst of shards that rise from the ring of ground that broke, between the radius `inner` and the
## radius `outer` around this node (its sound is the one of this scene's name in the sound table).
## Presentation only; it frees itself. It hurts nobody (ZoneShatter).

@export var shards: SpriteEmitter
@export_range(0.5, 10.0, 0.5, "suffix:s") var life_s := 3.0


## `inner` and `outer` (m): the ring the shards are born in.
func play(params: Dictionary) -> void:
	if shards != null:
		shards.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		shards.emission_ring_axis = Vector3.UP
		shards.emission_ring_height = 0.0
		shards.emission_ring_inner_radius = float(params.get("inner", 0.0))
		shards.emission_ring_radius = maxf(float(params.get("outer", 1.0)), 0.01)
		shards.set_active(true)
	get_tree().create_timer(life_s).timeout.connect(queue_free)


func _get_configuration_warnings() -> PackedStringArray:
	return (
		PackedStringArray()
		if shards != null
		else PackedStringArray(["The SpriteEmitter of the shards is missing."])
	)
