extends Node

## RFC-036 036f headless form of agent/flows/final_separation.json (Ctrl+Space with four Troggs around the wizard): the four
## own creatures of debug/orders_group.tscn get the retreat order through Orders (the call the key makes) and after
## `wait_s` seconds the case reads where they stand. PASS: every creature stands within `near_m` of the wizard, none is
## closer than `min_apart_m` to another (the avoidance keeps them from sinking in each other) and the loneliest one is no
## farther than `max_apart_m` from its closest mate (they gather around the wizard instead of drifting). Prints one line
## `retreat_spacing: PASS|FAIL {…}` and, headless, quits. The Druid of the bed stands out of sight (Group.foe_gap_m), so the
## retreat is not a fight.
## Run: Godot --headless --fixed-fps 60 --path game res://debug/retreat_spacing.tscn

@export var group: Node
@export var orders: Node
@export var expected := 4
@export var wait_s := 7.0
@export var near_m := 12.0
@export var min_apart_m := 1.0
@export var max_apart_m := 2.5
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
	var wizard := (group.get("world") as Node).call("local_wizard") as Node3D
	if own.size() < expected or wizard == null:
		return
	_started = true
	_run.call_deferred(own.duplicate(), wizard)


func _run(units: Array, wizard: Node3D) -> void:
	var tree := get_tree()
	for _i in 30:
		await tree.physics_frame
	orders.call("apply_for", 1, [], "retreat", wizard.global_position, wizard, 0.0)
	for _i in int(wait_s * Engine.physics_ticks_per_second):
		await tree.physics_frame
	var min_pair := INF
	var max_nearest := 0.0
	var far_from_wizard := 0.0
	for a in units.size():
		var nearest := INF
		for b in units.size():
			if a == b:
				continue
			var d := _flat(units[a]).distance_to(_flat(units[b]))
			nearest = minf(nearest, d)
			if b > a:
				min_pair = minf(min_pair, d)
		max_nearest = maxf(max_nearest, nearest)
		far_from_wizard = maxf(far_from_wizard, _flat(units[a]).distance_to(_flat(wizard)))
	var checks := {
		"near_wizard": far_from_wizard <= near_m,
		"not_sunk": min_pair >= min_apart_m,
		"gathered": max_nearest <= max_apart_m,
	}
	var ok := checks.values().all(func(v: bool) -> bool: return v)
	var report := {"checks": checks, "min_pair_m": snappedf(min_pair, 0.01), "max_nearest_m": snappedf(max_nearest, 0.01),
			"far_from_wizard_m": snappedf(far_from_wizard, 0.01)}
	print("retreat_spacing: %s %s" % ["PASS" if ok else "FAIL", JSON.stringify(report)])
	if quit_when_done and DisplayServer.get_name() == "headless":
		tree.quit(0 if ok else 1)


static func _flat(node: Node3D) -> Vector2:
	return Vector2(node.global_position.x, node.global_position.z)
