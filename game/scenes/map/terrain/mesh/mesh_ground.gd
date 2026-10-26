class_name MeshGround
extends GroundBackend

## The ground of a mesh map: the triangles of a MeshGroundData answered through MeshGroundRules (a roof wins over what lies
## under it). Static for now: the field does not move it yet (063-2b). What it does NOT do: build the cache (the import did)
## or collide (GroundCollision).

var data: MeshGroundData


func _init(ground: MeshGroundData) -> void:
	data = ground


func is_loaded() -> bool:
	return data != null and data.is_valid()


func height_at(x: float, z: float) -> float:
	return MeshGroundRules.height_in(x, z, data)


func is_on_ground(x: float, z: float) -> bool:
	return MeshGroundRules.triangle_in(x, z, data) >= 0


func normal_at(x: float, z: float) -> Vector3:
	return MeshGroundRules.normal_in(x, z, data)


func bounds() -> Rect2:
	return data.bounds


func lowest() -> float:
	return data.lowest_m


## The data never changes, so a worker thread shares it.
func sampler() -> Callable:
	return MeshGroundRules.height_in.bind(data)
