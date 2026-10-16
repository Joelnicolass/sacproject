extends Node

## F88 round 2 case (headless): the 150 creatures of debug/selection_many.tscn on High Noon get the march order of the
## pt88 playtest (80 m north, past the two tipis jwg1 Bld072 and Bld076) through Orders, the product's formation. Every
## physics tick the case reads each body. A body that still has its move order pending (UnitBody MOVE) and has not gone
## `PROGRESS_M` from where it last made progress for more than `STUCK_S` seconds is «trabada». PASS: none trabada and
## every body out of MOVE before `LIMIT_S`. It prints one line `crowd_tipi: PASS|FAIL {…}` and, with quit_when_done,
## quits. Run: Godot --headless --fixed-fps 60 --path game res://debug/crowd_tipi.tscn
## Before the fix (2026-10-16): 4 trabadas for good against the south faces of both tipis (Manahoar68, Trogg82 at Bld076;
## Manahoar104, Trogg130 at Bld072), MOVE with zero velocity until the end.

const STUCK_S := 2.0
const PROGRESS_M := 0.5
const LIMIT_S := 45.0

## The group of the scene (orders_group.gd): it spawns the creatures.
@export var group: Node
## The world's Orders (orders.gd): the order goes through it, as the player's does.
@export var orders: Node
## Where the march goes: the point of the pt88 flow (aim_ahead 80), on the far side of the tipis.
@export var goal := Vector3(1522.0, 0.0, 1435.0)
@export var facing := 0.0
@export var expected := 150
@export var quit_when_done := true

var _started := false


func _get_configuration_warnings() -> PackedStringArray:
	if group == null or orders == null:
		return PackedStringArray(["Asigná group y orders."])
	return PackedStringArray()


func _physics_process(_delta: float) -> void:
	if _started:
		return
	var own: Array = group.get("_own")
	var nav := get_tree().get_first_node_in_group(NavService.GROUP) as NavService
	if own.size() < expected or nav == null or not nav.is_ready():
		return
	_started = true
	_run.call_deferred(own.duplicate())


func _run(units: Array) -> void:
	var tree := get_tree()
	for _i in 30:
		await tree.physics_frame
	orders.call("apply_for", 1, units, "move", goal, null, facing)
	var count := units.size()
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var marks: Array[Vector2] = []
	var since := PackedInt32Array()
	var episode := PackedByteArray()
	for unit: Node3D in units:
		marks.append(_flat(unit))
	since.resize(count)
	episode.resize(count)
	var stuck := 0
	var worst_s := 0.0
	var stuck_at: Array = []
	var ticks := 0
	var walking := count
	var limit := int(LIMIT_S / dt)
	while ticks < limit and walking > 0:
		await tree.physics_frame
		ticks += 1
		walking = 0
		for i in count:
			var unit: Node3D = units[i]
			if not is_instance_valid(unit):
				continue
			var here := _flat(unit)
			if int(unit.get("mode")) != UnitBody.Mode.MOVE:
				marks[i] = here
				since[i] = 0
				episode[i] = 0
				continue
			walking += 1
			if here.distance_to(marks[i]) >= PROGRESS_M:
				marks[i] = here
				since[i] = 0
				episode[i] = 0
				continue
			since[i] += 1
			worst_s = maxf(worst_s, since[i] * dt)
			if since[i] * dt > STUCK_S and episode[i] == 0:
				episode[i] = 1
				stuck += 1
				if stuck_at.size() < 8:
					stuck_at.append("%s t=%.1fs at=(%.1f, %.1f)" % [unit.name, ticks * dt, here.x, here.y])
	var ok := stuck == 0 and walking == 0
	var report := {"stuck": stuck, "walking_at_end": walking, "worst_still_s": snappedf(worst_s, 0.01),
			"seconds": snappedf(ticks * dt, 0.01), "stuck_at": stuck_at}
	print("crowd_tipi: %s %s" % ["PASS" if ok else "FAIL", JSON.stringify(report)])
	if quit_when_done:
		tree.quit(0 if ok else 1)


static func _flat(node: Node3D) -> Vector2:
	return Vector2(node.global_position.x, node.global_position.z)
