extends SceneTree

## One-shot, with Godot: checks the result of tools/migrate/migrate_055o_audio.py. The Python script wrote the typed data
## without opening Godot (data/audio/cues/, the `cue` of 74 emitters, `sound` of 31 ParticleType and 6 BeamType, the Sound
## child of 6 FX scenes) and a snapshot of how every FX sounded before (055o_fx_parity.json). This one loads all of it and
## prints the parity report: every consumer has the streams and numbers of the cue it had, and the keys nobody used.
## It changes nothing. Both go away when 055o closes.
##   godot --headless --path . --script res://tools/migrate/migrate_055o_audio.gd
## Prints `PARITY <passed>/<total>` and `MIGRATE 055o PASS|FAIL`; exits 0 / 1.

const REFS := "res://debug/audio/sound_refs_cases.gd"
const SNAPSHOT := "res://tools/migrate/055o_fx_parity.json"


func _initialize() -> void:
	var refs: Object = (load(REFS) as GDScript).new()
	if not FileAccess.file_exists(SNAPSHOT):
		print("MIGRATE 055o FAIL falta %s (¿ya se cerró la migración?)" % SNAPSHOT)
		quit(1)
		return
	if not FileAccess.file_exists("res://assets/original/audio/sfx/char/bld1.wav"):
		print("Faltan los archivos de assets/original/audio (git lfs pull): la paridad de streams no se puede medir")
	var report: Dictionary = refs.parity_report(SNAPSHOT)
	var failures: PackedStringArray = report["failures"]
	for line in failures:
		print("PARITY FAIL %s" % line)
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SNAPSHOT))
	var unused: Array = snapshot.get("unused_keys", [])
	print("PARITY %d/%d" % [int(report["passed"]), int(report["total"])])
	print("Claves descartadas sin consumidor: %s" % ", ".join(PackedStringArray(unused)))
	var scan: Dictionary = refs.scan_emitters()
	var types: Dictionary = refs.count_fx_types()
	print("emisores tipados=%d por texto=%d sin cue=%d · ParticleType.sound=%d BeamType.sound=%d escenas FX=%d" % [
		int(scan["typed"]), int(scan["text"]), int(scan["null"]), int(types["particles"]), int(types["beams"]), int(types["scenes"])])
	var ok := failures.is_empty() and int(report["total"]) > 0 and int(scan["text"]) == 0 and int(scan["null"]) == 0
	print("MIGRATE 055o %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
