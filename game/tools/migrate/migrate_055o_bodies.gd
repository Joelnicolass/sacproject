extends SceneTree

## One-shot, with Godot: checks the result of tools/migrate/migrate_055o_bodies.py. The Python script wrote the typed data without
## opening Godot (the 67 creature sets and 15 wizard sets with named fields, the melee sets as their fallback, `sounds` in
## 67 creatures and 15 wizards, UnitSounds.summon in unit.tscn) and a snapshot of how every creature and wizard sounded before
## (055o_bodies_parity.json). This one loads all of it and prints the parity report: for every body and event the new set gives
## the same streams and numbers, and the files carry the human names. It changes nothing. Both go away when 055o closes.
##   godot --headless --path . --script res://tools/migrate/migrate_055o_bodies.gd
## Prints `BODIES PARITY <passed>/<total>` and `MIGRATE 055o-b PASS|FAIL`; exits 0 / 1.

const REFS := "res://debug/audio/sound_refs_cases.gd"
const SNAPSHOT := "res://tools/migrate/055o_bodies_parity.json"


func _initialize() -> void:
	var refs: Object = (load(REFS) as GDScript).new()
	if not FileAccess.file_exists(SNAPSHOT):
		print("MIGRATE 055o-b FAIL falta %s (¿ya se cerró la migración?)" % SNAPSHOT)
		quit(1)
		return
	if not FileAccess.file_exists("res://assets/original/audio/sfx/char/bld1.wav"):
		print("Faltan los archivos de assets/original/audio (git lfs pull): la paridad de streams no se puede medir")
	var report: Dictionary = refs.bodies_parity_report(SNAPSHOT)
	var failures: PackedStringArray = report["failures"]
	for line in failures:
		print("BODIES PARITY FAIL %s" % line)
	print("BODIES PARITY %d/%d" % [int(report["passed"]), int(report["total"])])
	var counts: Dictionary = refs.count_body_sets()
	print("creaturas con sounds=%d/%d magos=%d/%d summon en unit.tscn=%s sin fallback=%d" % [int(counts["creature_sets"]),
		int(counts["creatures"]), int(counts["wizard_sets"]), int(counts["wizards"]), counts["summon"], int(counts["without_fallback"])])
	var misnamed := _misnamed(counts)
	for line in misnamed:
		print("NOMBRE %s" % line)
	var stale: PackedStringArray = refs.stale_body_references()
	for line in stale:
		print("RESTO %s" % line)
	var ok := failures.is_empty() and int(report["total"]) > 0 and misnamed.is_empty() and stale.is_empty() \
		and int(counts["creature_sets"]) == 67 and int(counts["wizard_sets"]) == 15 and bool(counts["summon"]) \
		and int(counts["without_fallback"]) == 0
	print("MIGRATE 055o-b %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


## Creature sets whose file is not the snake_case of the display name of their creature (the two Faestus add their god).
func _misnamed(_counts: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open("res://data/catalog/creatures")
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var type := load("res://data/catalog/creatures/" + file) as CreatureType
		if type == null or type.sounds == null:
			continue
		var wanted := type.display_name.to_lower().replace(" ", "_")
		var name := type.sounds.resource_path.get_file().get_basename()
		if name != wanted and not name.begins_with(wanted + "_"):
			out.append("%s: %s y debía ser %s" % [file, name, wanted])
	return out
