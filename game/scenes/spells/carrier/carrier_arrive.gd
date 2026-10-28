class_name CarrierArrive
extends Node

## What a SpellCarrier does at each moment of its life: when the cast starts (`begin`), when it is
## let go (`released`), on its way (`along`, every tick) and when it reaches its target (`arrive`).
## The base does nothing. The server (or solo) only. It does not move the carrier (SpellCarrier) nor
## choose who comes next (ChainHop): a kind of carrier decides the rest.


func begin(_carrier: SpellCarrier, _wizard: Node3D, _spell: SpellType, _target: Node3D) -> void:
	pass


func released(_carrier: SpellCarrier, _target: Node3D) -> void:
	pass


## Every tick of the flight, before the carrier moves.
func along(_carrier: SpellCarrier) -> void:
	pass


## The carrier reached its target (a body, or a point on the land).
func arrive(_carrier: SpellCarrier) -> void:
	pass
