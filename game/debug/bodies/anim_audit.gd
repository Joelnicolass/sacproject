extends Node

## Debug: audits the animation of every model scene (scenes/bodies/models/) against the type data of every wizard, creature,
## peasant and the Sac Doctor, and prints a table (PASS / WARN / FAIL per model and role) and the counts per check.
## Run headless:  godot_run.sh Godot --headless --path . res://debug/bodies/anim_audit.tscn [-- --verbose] [--out=<file>]
## `--verbose` prints the PASS rows too; `--out=` also writes the whole table to a file. Prints ANIM AUDIT PASS when no row FAILs
## (WARN rows are findings to read, not errors). Models of the type data with no scene (static meshes) and scenes no type uses
## are listed. It changes nothing.

const CHECKS: PackedStringArray = ["map", "clip", "rate", "loop", "seam", "motion", "finite", "drift", "hands"]

var _verbose := false
var _out_path := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		_verbose = _verbose or arg == "--verbose"
		if arg.begins_with("--out="):
			_out_path = arg.substr(6)
	call_deferred("_run")


func _run() -> void:
	var owners := AnimExpect.owners()
	var models: Array = owners.keys()
	for file in DirAccess.get_files_at(BodyModel.SCENE_DIR):
		if file.ends_with(".tscn") and not models.has(file.get_basename()):
			models.append(file.get_basename())
	models.sort()
	var rows: Array[Dictionary] = []
	var unmapped: Array[Dictionary] = []
	var holds := PackedStringArray()
	var without_scene := PackedStringArray()
	var without_owner := PackedStringArray()
	for model: String in models:
		if not BodyModel.exists(model):
			without_scene.append("%s (%s)" % [model, ", ".join(_who(owners[model]))])
			continue
		if not owners.has(model):
			without_owner.append(model)
		var audit := AnimModelAudit.new()
		audit.audit(model, owners.get(model, []))
		rows.append_array(audit.rows)
		unmapped.append_array(audit.unmapped)
		holds.append_array(audit.holds)
	var lines := _table(rows)
	if not _out_path.is_empty():
		var file := FileAccess.open(_out_path, FileAccess.WRITE)
		if file != null:
			file.store_string("\n".join(lines) + "\n")
	for line in lines:
		if _verbose or not line.begins_with("PASS"):
			print(line)
	_print_unmapped(unmapped)
	print("ANIM AUDIT HOLD (intentional still pose): %s" % (", ".join(holds) if not holds.is_empty() else "none"))
	print("ANIM AUDIT models without a scene (static meshes): %s" % (", ".join(without_scene) if not without_scene.is_empty() else "none"))
	print("ANIM AUDIT scenes no type uses: %s" % (", ".join(without_owner) if not without_owner.is_empty() else "none"))
	var fails := _print_summary(rows, models.size() - without_scene.size())
	print("ANIM AUDIT %s" % ("PASS" if fails == 0 else "FAIL"))
	get_tree().quit(0 if fails == 0 else 1)


func _table(rows: Array[Dictionary]) -> PackedStringArray:
	var lines := PackedStringArray()
	for row in rows:
		var notes := PackedStringArray()
		for check in CHECKS:
			var result: Array = (row["checks"] as Dictionary).get(check, [])
			if not result.is_empty() and not str(result[1]).is_empty():
				notes.append("%s %s: %s" % [check, result[0], result[1]])
		lines.append("%s %-12s %-10s %-5s %4d  %s" % [row["status"], row["model"], row["role"], row["tag"], row["frames"], "; ".join(notes)])
	return lines


func _print_unmapped(unmapped: Array[Dictionary]) -> void:
	var by_role: Dictionary = {}
	for item in unmapped:
		var key := "%s -> %s" % [item["role"], item["fallback"]]
		if not by_role.has(key):
			by_role[key] = []
		(by_role[key] as Array).append("%s/%s%s" % [item["model"], item["tag"], " (%s)" % item["detail"] if not str(item["detail"]).is_empty() else ""])
	for key: String in by_role:
		var list: Array = by_role[key]
		print("ANIM AUDIT UNMAPPED %d  %s  [%s]" % [list.size(), key, ", ".join(list) if _verbose else ", ".join(list.slice(0, 4)) + ("..." if list.size() > 4 else "")])


## Prints the counts per check and returns how many rows FAIL.
func _print_summary(rows: Array[Dictionary], model_count: int) -> int:
	var totals := {"PASS": 0, "WARN": 0, "FAIL": 0}
	var wraps := 0
	var per_check: Dictionary = {}
	for row in rows:
		totals[row["status"]] += 1
		wraps += 1 if str(((row["checks"] as Dictionary).get("seam", ["", ""]) as Array)[1]).begins_with("seam") else 0
		for check: String in row["checks"]:
			if not per_check.has(check):
				per_check[check] = {"PASS": 0, "WARN": 0, "FAIL": 0}
			per_check[check][(row["checks"][check] as Array)[0]] += 1
	print("ANIM AUDIT models %d, rows (model x role) %d: PASS %d  WARN %d  FAIL %d" % [model_count, rows.size(), totals["PASS"], totals["WARN"], totals["FAIL"]])
	for check in CHECKS:
		if per_check.has(check):
			var c: Dictionary = per_check[check]
			print("ANIM AUDIT check %-7s PASS %4d  WARN %4d  FAIL %4d" % [check, c["PASS"], c["WARN"], c["FAIL"]])
	print("ANIM AUDIT loops whose last frame is more than 5%% of the size from the first: %d (a normal one-frame step at 30 fps; WARN only when the wrap is also over 1.5x the clip's own frame step)" % wraps)
	return totals["FAIL"]


func _who(list: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for owner: Dictionary in list:
		out.append(owner["who"])
	return out
