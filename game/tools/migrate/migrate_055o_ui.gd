extends SceneTree

## One-shot, with Godot: checks the result of tools/migrate/migrate_055o_ui.py. The Python script wrote the typed data without
## opening Godot (data/audio/cues/{ui_click,ui_book_click,menu_open,menu_back}.tres, `click` on UiClickSounds in sound_bus.tscn,
## the `ui_sound` cue of spell_slot.tscn, the three cues of MenuSounds in radial_menu.tscn) and a snapshot of how every UI event
## sounded before (055o_ui_parity.json). This one loads all of it and prints the parity report: every event has the streams,
## numbers, cue file and log event it had. It changes nothing. Both go away when 055o closes.
##   godot --headless --path . --script res://tools/migrate/migrate_055o_ui.gd
## Prints `UI PARITY <passed>/<total>` and `MIGRATE 055o-d PASS|FAIL`; exits 0 / 1.

const REFS := "res://debug/audio/sound_refs_cases.gd"
const SNAPSHOT := "res://tools/migrate/055o_ui_parity.json"


func _initialize() -> void:
	var refs: Object = (load(REFS) as GDScript).new()
	if not FileAccess.file_exists(SNAPSHOT):
		print("MIGRATE 055o-d FAIL falta %s (¿ya se cerró la migración?)" % SNAPSHOT)
		quit(1)
		return
	if not FileAccess.file_exists("res://assets/original/audio/sfx/char/bld1.wav"):
		print("Faltan los archivos de assets/original/audio (git lfs pull): la paridad de streams no se puede medir")
	var report: Dictionary = refs.ui_parity_report(SNAPSHOT)
	var failures: PackedStringArray = report["failures"]
	for line in failures:
		print("UI PARITY FAIL %s" % line)
	print("UI PARITY %d/%d" % [int(report["passed"]), int(report["total"])])
	var counts: Dictionary = refs.count_ui_cues()
	print("clic en sound_bus=%s dato ui_sound en spell_slot=%s cues del MenuSounds=%d/3" % [counts["click"], counts["slot"], int(counts["menu"])])
	var stale: PackedStringArray = refs.stale_ui_references()
	for line in stale:
		print("RESTO %s" % line)
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT))
	print("Claves descartadas sin consumidor: %s" % ", ".join(PackedStringArray(snapshot.get("unused_keys", []))))
	var ok := failures.is_empty() and int(report["total"]) > 0 and stale.is_empty() and bool(counts["click"]) \
		and bool(counts["slot"]) and int(counts["menu"]) == 3 and not FileAccess.file_exists("res://data/audio/ui.tres")
	print("MIGRATE 055o-d %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
