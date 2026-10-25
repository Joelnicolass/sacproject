extends SceneTree

## One-shot, with Godot: checks the result of tools/migrate/migrate_055o_match.py. The Python script wrote the typed data without
## opening Godot (GodType.music and ambience in the five gods, the A* one-shots inside the ambience sets, advisor.tscn with its 14
## AdvisorLine, the cues of the sacrifice and of the souls, the director sockets of match.tscn and boot.tscn) and a snapshot of how the
## match sounded before (055o_match_parity.json). This one loads all of it and prints the parity report: for every god, line and cue
## the new data gives the same streams and numbers. It changes nothing. Both go away when 055o closes.
##   godot --headless --path . --script res://tools/migrate/migrate_055o_match.gd
## Prints `MATCH PARITY <passed>/<total>` and `MIGRATE 055o-c PASS|FAIL`; exits 0 / 1.

const REFS := "res://debug/audio/match_refs_cases.gd"
const SNAPSHOT := "res://tools/migrate/055o_match_parity.json"


func _initialize() -> void:
	if not FileAccess.file_exists(SNAPSHOT):
		print("MIGRATE 055o-c FAIL falta %s (¿ya se cerró la migración?)" % SNAPSHOT)
		quit(1)
		return
	if not FileAccess.file_exists("res://assets/original/audio/sfx/sacr/sac0.wav"):
		print("Faltan los archivos de assets/original/audio (git lfs pull): la paridad de streams no se puede medir")
	var refs: Object = (load(REFS) as GDScript).new()
	var report: Dictionary = refs.parity_report(SNAPSHOT)
	var failures: PackedStringArray = report["failures"]
	for line in failures:
		print("MATCH PARITY FAIL %s" % line)
	print("MATCH PARITY %d/%d" % [int(report["passed"]), int(report["total"])])
	var counts: Dictionary = refs.match_counts()
	print("dioses=%d/%d lineas=%d rechazos=%d avisos=%d consejero en match=%s canal de voces=%s default_music=%s musica del menu=%s cues del sacrificio=%s" % [
		int(counts["gods_typed"]), int(counts["gods"]), int(counts["lines"]), int(counts["refusals"]), int(counts["watch"]),
		counts["advisor_instance"], counts["command_channel"], counts["default_music"], counts["boot_music"], counts["sacrifice_cues"]])
	var stale: PackedStringArray = refs.stale_references()
	for line in stale:
		print("RESTO %s" % line)
	var ok := failures.is_empty() and int(report["total"]) > 0 and stale.is_empty() and int(counts["gods_typed"]) == 5 \
		and int(counts["lines"]) == 14 and int(counts["refusals"]) == 7 and int(counts["watch"]) == 8 and bool(counts["advisor_instance"]) \
		and bool(counts["command_channel"]) and bool(counts["default_music"]) and bool(counts["boot_music"]) and bool(counts["sacrifice_cues"])
	print("MIGRATE 055o-c %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
