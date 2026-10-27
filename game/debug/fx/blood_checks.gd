class_name BloodChecks
extends Node

## The checks of the blood lab (debug only). `run` needs a window (GroundScars paints nothing headless); `run_headless` proves a
## headless process (the dedicated server) bleeds nothing. Each check prints `BLOOD <check>: PASS|FAIL`, then `BLOOD PASS|FAIL`,
## and the tree quits 0 / 1. Watchdog: `timeout_s` real seconds.

const SPRAY: ParticleType = preload("res://data/fx/blood_hit.tres")
const HEAVY: ParticleType = preload("res://data/fx/blood_hit_heavy.tres")

@export var trogg_a: Node3D
@export var trogg_b: Node3D
## A body whose BloodFx wears data/fx/blood/none.tres.
@export var stone: Node3D
## The checks of the flash, the gib and the option (they share `check` and `wait`).
@export var more: BloodMoreChecks
@export var timeout_s := 30.0

var _failed := false
var _played: Array[Dictionary] = []


## Takes `fraction` of the body's maximum off its health, as a hit shows on any peer (Health.changed).
static func hit(body: Node3D, fraction: float) -> void:
	var health := Health.of(body)
	if health != null and health.maximum > 0.0:
		health.current = maxf(health.current - health.maximum * fraction, 1.0)


static func blood_of(body: Node3D) -> BloodFx:
	for child in body.get_children():
		if child is BloodFx:
			return child
	return null


func run() -> void:
	_arm_watchdog()
	FxBus.played.connect(_on_played)
	await wait(1.0)
	var scars := GroundScars.of(self)
	check("ground scars active (window)", scars != null)
	var a := blood_of(trogg_a)
	var b := blood_of(trogg_b)
	# 1. A 20 % hit sprays once at the center and paints one mark.
	GroundScars.log_lines.clear()
	hit(trogg_a, 0.2)
	await wait(0.05)
	check("light spray", a.sprays == 1 and _played_near(SPRAY, BodyFacts.point(trogg_a, BodyFacts.Socket.CENTER), 0.15))
	check("light mark", a.marks == 1 and scars != null and scars.painted_tiles() > 0 and _log_has("painted blud.png"))
	# 2. A 45 % hit is heavy: the heavy spray and three marks.
	hit(trogg_b, 0.45)
	await wait(0.05)
	check("heavy spray", b.sprays == 1 and _played_near(HEAVY, BodyFacts.point(trogg_b, BodyFacts.Socket.CENTER), 0.15))
	check("heavy marks", b.marks == 3)
	# 3. Feet far over the ground: the spray, but no mark.
	await wait(0.4)
	trogg_a.global_position.y += 3.0
	GroundScars.log_lines.clear()
	hit(trogg_a, 0.1)
	await wait(0.05)
	check("flier leaves no mark", a.sprays == 2 and a.marks == 1 and _log_has("too far"))
	trogg_a.global_position.y -= 3.0
	# 4. Ten 1 % hits in one second (a poison): one to three sprays.
	await wait(0.4)
	var before := b.sprays
	for i in 10:
		hit(trogg_b, 0.01)
		await wait(0.1)
	check("no spam (%d sprays)" % (b.sprays - before), b.sprays - before >= 1 and b.sprays - before <= 3)
	# 5. A type with nothing: five hits, nothing.
	var s := blood_of(stone)
	for i in 5:
		hit(stone, 0.1)
		await wait(0.3)
	check("none bleeds nothing", s.sprays == 0 and s.marks == 0 and _played_near(SPRAY, BodyFacts.point(stone, BodyFacts.Socket.CENTER), 0.5) == false)
	# 6. A wound as a client receives it (060s): a new index paints once; the same one again paints nothing.
	var next := BloodRules.wound_of(BodyFacts.point(trogg_a, BodyFacts.Socket.FEET), BloodRules.index_of(a.wound) + 1, false)
	var shown := a.sprays
	a.wound = next
	a.wound = next
	check("received wound paints once", a.sprays == shown + 1)
	if more != null:
		await more.run(self)
	_finish()


func run_headless() -> void:
	_arm_watchdog()
	await wait(0.3)
	var any_active := false
	for body: Node3D in [trogg_a, trogg_b, stone]:
		hit(body, 0.45)
		any_active = any_active or blood_of(body).is_active()
	await wait(0.1)
	check("headless: no BloodFx active", not any_active and blood_of(trogg_a).sprays == 0)
	check("headless: the server still decides the wound", BloodRules.index_of(blood_of(trogg_a).wound) == 1)
	check("headless: no ground marks", GroundScars.of(self) == null)
	_finish()


func _on_played(kind: StringName, fx: Resource, at: Vector3) -> void:
	_played.append({"kind": kind, "fx": fx, "at": at})


func _played_near(fx: ParticleType, at: Vector3, within_m: float) -> bool:
	for entry in _played:
		if entry["fx"] == fx and (entry["at"] as Vector3).distance_to(at) <= within_m:
			return true
	return false


## Since the log was last cleared.
static func _log_has(text: String) -> bool:
	for line in GroundScars.log_lines:
		if line.contains(text):
			return true
	return false


func check(label: String, ok: bool) -> void:
	_failed = _failed or not ok
	print("BLOOD %s: %s" % [label, "PASS" if ok else "FAIL"])


func _finish() -> void:
	print("BLOOD %s" % ("FAIL" if _failed else "PASS"))
	get_tree().quit(1 if _failed else 0)


func _arm_watchdog() -> void:
	get_tree().create_timer(timeout_s, true, false, true).timeout.connect(_on_timeout)


func _on_timeout() -> void:
	print("BLOOD FAIL timeout")
	get_tree().quit(1)


## Waits `seconds` of real time (about the same match seconds: BloodFx counts MatchClock ticks).
func wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
