class_name SpellProjectile
extends Node3D

## Contract of a spell projectile (RFC-041). SpellSpawner instances its scene and calls `setup(data)` with the
## keys of the cast (position, target, caster, slot, speed, damage…) before it enters the tree, on the server
## and on every client. The server (or solo) moves it; clients get the position and play the trail locally.


func setup(_data: Dictionary) -> void:
	pass
