extends Node

## Observation helper (F98 playtest, RFC-029 029d). Read-only: casts nothing, moves nothing, edits no rule.
##   start(type_name)  watches FxBus's beams of that BeamType once per drawn frame. For each beam it prints
##             «BEAM fin vivo X s cuadros N cambios C inicio→fin L m desvío_fin E m» when it hides:
##             X = seconds visible, C = shapes after the first, E = largest distance between the beam's
##             end and the center (Collision) of the unit nearest to it while visible (group `unit` only:
##             a dead unit leaves it), then «blanco» = the node the end follows (`_follow`) and
##             «desvío_blanco» = largest distance from the end to that node's center.
##   report()  read-only summary line.
## Props for wait_until / assert: beams_done, last_seconds, last_changes, last_end_error_m, last_length_m.
## Reads the BeamFx children of FxBus with get() (its time `_t`, shape `_shape`, ends `_from`/`_to`).

var beams_done := 0
var last_seconds := 0.0
var last_frames := 0
var last_changes := 0
var last_end_error_m := 0.0
var last_length_m := 0.0
## Name of the node the beam's end followed («ninguno» = it stayed on the point it was given), and the
## largest distance between the end and that node's center (Collision) while both were visible.
var last_target := ""
var last_target_error_m := -1.0

var _type := ""
var _live: Dictionary = {}
var _summary: PackedStringArray = []


func _ready() -> void:
	process_priority = 1000


func start(type_name: String = "lightning") -> String:
	_type = type_name
	return "mirando rayos %s" % type_name


## The BeamFx of the type that FxBus shows now, found among its children (no product API).
func _visible_beams() -> Array:
	var out := []
	for child in FxBus.get_node("%Beams").get_children():
		if child is BeamFx and (child as Node3D).visible and child.get("type") != null \
				and String((child.get("type") as Resource).resource_path).get_file().get_basename() == _type:
			out.append(child)
	return out


func _process(delta: float) -> void:
	if _type.is_empty():
		return
	var now := _visible_beams()
	for beam in now:
		var id: int = (beam as Object).get_instance_id()
		var row: Dictionary = _live.get(id, {"t": 0.0, "frames": 0, "changes": 0, "err": 0.0, "len": 0.0})
		row["t"] = float(row["t"]) + delta
		row["frames"] = int(row["frames"]) + 1
		row["changes"] = maxi(int(row["changes"]), int(beam.get("_shape")))
		var end: Vector3 = beam.get("_to")
		row["err"] = maxf(float(row["err"]), _nearest_center_distance(end))
		row["len"] = (beam.get("_from") as Vector3).distance_to(end)
		var target: Variant = beam.get("_follow")
		if target != null and is_instance_valid(target) and (target as Node).is_inside_tree():
			var center := _center_of(target as Node3D)
			row["target"] = String((target as Node).name)
			row["target_err"] = maxf(float(row.get("target_err", 0.0)), center.distance_to(end))
		elif not row.has("target"):
			row["target"] = "ninguno"
		_live[id] = row
	var ids := []
	for beam in now:
		ids.append((beam as Object).get_instance_id())
	for id in _live.keys():
		if not ids.has(id):
			_close(_live[id])
			_live.erase(id)


func _close(row: Dictionary) -> void:
	beams_done += 1
	last_seconds = float(row["t"])
	last_frames = int(row["frames"])
	last_changes = int(row["changes"])
	last_end_error_m = float(row["err"])
	last_length_m = float(row["len"])
	last_target = str(row.get("target", "ninguno"))
	last_target_error_m = float(row.get("target_err", -1.0))
	var line := "vivo %.3f s cuadros %d cambios %d inicio→fin %.1f m desvío_fin %.2f m blanco %s desvío_blanco %.2f m" % [last_seconds, last_frames, last_changes, last_length_m, last_end_error_m, last_target, last_target_error_m]
	_summary.append(line)
	print("BEAM fin " + line)


func _center_of(body: Node3D) -> Vector3:
	var col := body.get_node_or_null("Collision") as Node3D
	return (col if col != null else body).global_transform.origin


func _nearest_center_distance(at: Vector3) -> float:
	var best := INF
	for unit in get_tree().get_nodes_in_group("unit"):
		var col := (unit as Node).get_node_or_null("Collision") as Node3D
		if col != null:
			best = minf(best, col.global_transform.origin.distance_to(at))
	return best if best < INF else -1.0


func report() -> String:
	return "rayos %d · %s" % [beams_done, " | ".join(_summary)]
