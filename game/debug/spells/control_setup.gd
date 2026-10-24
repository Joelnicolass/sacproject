extends Node

## Debug of cast_control.tscn: after the targets are born, the Druid puts its Life Shield on (the ability would do it in a fight) so the
## four control spells can be seen refusing a protected body. It only starts a ward; it casts nothing.

@export var arena: Node3D
## Name of the body in `arena` that gets the shield (rock_hit.gd names them <Tag><n>).
@export var shielded := "Nmuh3"
@export var after_frames := 30


func _ready() -> void:
	for _frame in after_frames:
		await get_tree().physics_frame
	var body := arena.get_node_or_null(shielded) if arena else null
	var shield := LifeShield.of(body)
	if shield != null:
		shield.start(100000)
		print("control_setup: %s with Life Shield" % shielded)
