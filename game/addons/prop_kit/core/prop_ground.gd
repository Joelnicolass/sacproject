@tool
class_name PropGround
extends Resource

## Where props may stand, for a scatter: the area, the height and normal (3D), and how welcome a
## prop is at each point (0 never, 1 fully). This base is open, flat ground at height 0 over an
## empty area: use PropFlatGround or PropRayGround (3D), or write the game's own as a script that
## extends PropGround and answers from its terrain. Such a script needs `@tool`: the scatter calls
## it in the editor. Points are on the ground plane, in global coordinates: (x, z) in 3D, (x, y)
## in 2D.


## Gets ready to answer for one run of `scatter` (the PropScatter3D / PropScatter2D node): find the
## terrain, read its data. False = not ready: the scatter plants nothing and says why.
func begin(_scatter: Node) -> bool:
	return true


## The outline the editor draws (ground plane, global coordinates): the bounds by default.
func editor_outline() -> PackedVector2Array:
	var rect := bounds()
	if not rect.has_area():
		return PackedVector2Array()
	var corner_b := Vector2(rect.end.x, rect.position.y)
	var corner_d := Vector2(rect.position.x, rect.end.y)
	return PackedVector2Array([rect.position, corner_b, rect.end, corner_d])


## The area to scatter over.
func bounds() -> Rect2:
	return Rect2()


## Height of the ground at `at` (3D).
func height_at(_at: Vector2) -> float:
	return 0.0


## Up direction of the ground at `at` (3D; unit length).
func normal_at(_at: Vector2) -> Vector3:
	return Vector3.UP


## How welcome a prop is at `at`: 0 never (a hole, water, a road), 1 fully; in between thins them.
func weight_at(_at: Vector2) -> float:
	return 1.0
