class_name RowFormation
extends FormationType

## The formations laid in rows: line, flanks, phalanx and skirmish. Rows of `row_size` bodies stand
## one behind the other, `spacing` apart (an extension: the original cuts at 12 bodies); 0 = a
## single row.

enum Anchor { CENTER, LEFT, RIGHT }

@export var row_size := 0
## CENTER: the row is centered on the order point. LEFT / RIGHT: it stands beside it (the flanks); a
## guarded or followed body (not an attack) pushes it further out.
@export var anchor := Anchor.CENTER
## Every other body stands half a step behind (skirmish). Guarding pushes the whole line ahead of
## the guarded body.
@export var stagger := false
## Guarding opens the first row around the guarded body (line).
@export var guard_flank := false
## Guarding stands the rows behind the guarded body, `guard_back_m` plus the target distance
## (phalanx).
@export var guard_behind := false
@export var guard_back_m := 6.0


func slots(count: int, spacing: float, target_distance: float, command: int) -> Array[Vector2]:
	var per_row := _per_row(count)
	var result: Array[Vector2] = []
	var guard := command == UnitOrders.Command.GUARD
	var dist := 0.5 * sqrt(2.0) * spacing
	for i in count:
		var row := floori(float(i) / per_row)
		var col := i % per_row
		var n := mini(per_row, count - row * per_row)
		var x := -0.5 * (n - 1) * spacing + spacing * col
		match anchor:
			Anchor.LEFT:
				x = -(n * spacing) + spacing * col
				if target_distance > 0.0 and command != UnitOrders.Command.ATTACK:
					x -= target_distance - spacing
			Anchor.RIGHT:
				x = spacing + spacing * col
				if target_distance > 0.0 and command != UnitOrders.Command.ATTACK:
					x += target_distance - spacing
		if row == 0 and guard_flank and target_distance > 0.0 and guard:
			if n % 2 == 1:
				x += -target_distance if 2 * col < n + 1 else target_distance - spacing
			else:
				x += (
					-(target_distance - 0.5 * spacing)
					if 2 * col < n
					else target_distance - 0.5 * spacing
				)
		var y := float(-row * spacing)
		if stagger:
			y = -dist if (i & 1) == 1 else 0.0
			if target_distance > 0.0 and guard:
				y += target_distance + dist
		elif guard_behind and target_distance > 0.0 and guard:
			y -= guard_back_m + target_distance
		result.append(Vector2(x, y))
	return result


func row_count(count: int) -> int:
	return ceili(float(count) / float(maxi(_per_row(count), 1)))


func match_row_size(count: int) -> int:
	return _per_row(count) if row_size > 0 and not stagger else 0


func row_width(count: int, spacing: float) -> float:
	return (_per_row(count) - 1) * spacing


func _per_row(count: int) -> int:
	return maxi(count, 1) if row_size <= 0 else mini(row_size, maxi(count, 1))
