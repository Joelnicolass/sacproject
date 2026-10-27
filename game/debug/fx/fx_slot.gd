@tool
class_name FxSlot
extends Marker3D

## A spot of the gallery or the lab where one effect is shown: the ParticleType is assigned in the inspector (drag a .tres from data/fx),
## and `play` sends it through FxBus from where the marker stands. It plays nothing by itself and holds no pool.

@export var fx: ParticleType


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if fx != null else PackedStringArray(["Asigná `fx` (un ParticleType de data/fx)."])


## The effect once, at this marker.
func play() -> void:
	if fx != null:
		FxBus.play(fx, global_position)
