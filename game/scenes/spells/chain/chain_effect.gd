class_name ChainEffect
extends Node

## What one jump of a chain does (Chain Lightning's bolt, Rainbow's arc and its cure). ChainHop calls `hop` when a jump leaves and
## `land` when it arrives; the base does nothing. It keeps no state of the chain (ChainHop owns who was hit). Server (or solo) only.


## A jump leaves `from` toward `body` (null = a point on the land: `point`).
func hop(_chain: ChainHop, _from: Vector3, _body: Node3D, _point: Vector3) -> void:
	pass


## The jump arrived at `body` (null = the land at `point`).
func land(_chain: ChainHop, _body: Node3D, _point: Vector3) -> void:
	pass
