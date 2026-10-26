class_name GroundBackend
extends RefCounted

## What a ground can answer, whatever it is made of: the one contract GroundSurface forwards to. This base is a map with no
## land (every answer is «nothing here»); GridGround (the 10 m lattice) and MeshGround (a free mesh) fill it in. What it does
## NOT do: hold how far the ground has moved (GroundField), pick between backends (GroundSurface) or draw anything.


## True once there is land to ask about.
func is_loaded() -> bool:
	return false


## Land height under (x, z) in world units, NAN over a hole or off the land.
func height_at(_x: float, _z: float) -> float:
	return NAN


## True when land lies under (x, z).
func is_on_ground(_x: float, _z: float) -> bool:
	return false


## Unit normal (pointing up) of the land under (x, z); straight up when there is none.
func normal_at(_x: float, _z: float) -> Vector3:
	return Vector3.UP


## The map's footprint on the ground (x, z in metres).
func bounds() -> Rect2:
	return Rect2()


## The lowest land vertex (0 without land).
func lowest() -> float:
	return 0.0


## A Callable(x, z) -> float that answers like `height_at` from a copy taken now and reads no node (WorkerThreadPool-safe).
func sampler() -> Callable:
	return height_at
