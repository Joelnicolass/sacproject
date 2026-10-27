class_name WedgeFormation
extends FormationType

## The wedge: a V pointing at the front, its tip `3·0.5·√2·scale` ahead of the order point.
## Ref: state.d:467-472.

## On an attack the wedge has no advance: the tip stands on the order point.
@export var attack_forward := true


func slots(count: int, spacing: float, target_distance: float, command: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var unit := maxf(spacing, target_distance / 1.5)
	var root2 := sqrt(2.0)
	var advance := 0.0 if attack_forward and command == UnitOrders.Command.ATTACK else 3.0 * 0.5 * root2 * unit
	var offset := Vector2(0.0, advance)
	var half := floori(count / 2.0)
	for i in count:
		if i <= half:
			result.append(offset - (half - i) * 0.5 * Vector2(root2, root2) * unit)
		else:
			result.append(offset + (i - half) * 0.5 * Vector2(root2, -root2) * unit)
	return result
