class_name CastEmitters
extends FxScene

## The sprites a spell throws at a place while the wizard casts it (the earth that rises where
## Bovine Intervention's cow will come out), played on every peer by FxBus.broadcast_scene: its
## SpriteEmitter children are on for as many ticks as the cast lasts, then off, and the node frees
## itself when the last sprite is gone. Presentation only. It hurts nobody and does not follow
## anything.

## Seconds the last sprites need to fade after the emitters go off.
@export_range(0.0, 5.0, 0.1, "suffix:s") var tail_s := 1.0


## FxBus.play_scene: `ticks` the cast lasts.
func play(params: Dictionary) -> void:
	var seconds := float(maxi(1, int(params.get("ticks", 1)))) / MatchClock.TICKS_PER_SECOND_F
	_switch(true)
	get_tree().create_timer(seconds).timeout.connect(_off)


func _off() -> void:
	_switch(false)
	get_tree().create_timer(tail_s).timeout.connect(queue_free)


func _switch(on: bool) -> void:
	for child in get_children():
		if child is SpriteEmitter:
			(child as SpriteEmitter).set_active(on)
