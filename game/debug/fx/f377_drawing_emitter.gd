extends SpriteEmitter

## F377 probe only (RFC-053 053h): a SpriteEmitter that draws even in a headless process. Setting `emitting = true` then
## runs CPUParticles3D's first update (which reads the global transform) as in a windowed game, so the headless run
## reproduces the out-of-tree `get_global_transform` error. Nothing in the product uses it.


func _is_headless() -> bool:
	return false
